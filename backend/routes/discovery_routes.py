from __future__ import annotations

from flask import Blueprint, request
from sqlalchemy import distinct, func, or_
from sqlalchemy.orm import load_only

from extensions import db
from models.branch import Branch
from models.category import Category
from models.category_filter_group_map import CategoryFilterGroupMap
from models.filter_group import FilterGroup
from models.filter_value import FilterValue
from models.product import Product
from models.product_filter_map import ProductFilterMap
from models.review import Review
from models.search_term import SearchTerm
from services.runtime_cache import runtime_ttl_cache
from utils.api import (
    items_response,
    pagination_payload,
    parse_pagination_args,
    success_response,
)


discovery_bp = Blueprint('discovery', __name__)


class _ListPaginationResult:
    def __init__(self, items: list[Product], total: int):
        self.items = items
        self.total = total


@discovery_bp.get('/search')
def search_products():
    search_query = (request.args.get('q') or '').strip()
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    filter_value_ids = _parse_filter_value_ids(request.args.get('filter_value_ids'))
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    rows = run_discovery_product_query(
        category_id=category_id,
        branch_id=branch_id,
        language=language,
        region_code=region_code,
        search_query=search_query,
        filter_value_ids=filter_value_ids,
        hide_from_search=True,
        page=page,
        per_page=per_page,
    )
    return success_response(
        query=search_query,
        items=serialize_discovery_products(
            rows.items,
            language=language,
            region_code=region_code,
        ),
        pagination=pagination_payload(page=page, per_page=per_page, total=rows.total),
        filters=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
            language=language,
            region_code=region_code,
        ),
    )


@discovery_bp.get('/popular-searches')
def list_popular_searches():
    term_type = (request.args.get('type') or '').strip().lower()
    cache_key = f'popular-searches:type={term_type or "all"}'

    def build_items():
        query = SearchTerm.query.filter_by(is_active=True)
        if term_type:
            query = query.filter(SearchTerm.term_type == term_type)
        rows = query.order_by(SearchTerm.sort_order.asc(), SearchTerm.term.asc()).all()
        return [_serialize_search_term(row) for row in rows]

    items = runtime_ttl_cache.get_or_set(cache_key, 180, build_items)
    rows = items
    return items_response(items, total=len(rows))


@discovery_bp.get('/filters')
def list_filters():
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    search_query = (request.args.get('q') or '').strip()
    return success_response(
        items=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
            language=language,
            region_code=region_code,
        )
    )


@discovery_bp.get('/categories/<int:category_id>/products')
def list_category_products(category_id: int):
    branch_id = request.args.get('branch_id', type=int)
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    search_query = (request.args.get('q') or '').strip()
    filter_value_ids = _parse_filter_value_ids(request.args.get('filter_value_ids'))
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    rows = run_discovery_product_query(
        category_id=category_id,
        branch_id=branch_id,
        language=language,
        region_code=region_code,
        search_query=search_query,
        filter_value_ids=filter_value_ids,
        hide_from_search=False,
        page=page,
        per_page=per_page,
    )
    return success_response(
        items=serialize_discovery_products(
            rows.items,
            language=language,
            region_code=region_code,
        ),
        pagination=pagination_payload(page=page, per_page=per_page, total=rows.total),
        filters=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
            language=language,
            region_code=region_code,
        ),
    )


def run_discovery_product_query(
    *,
    category_id: int | None,
    branch_id: int | None,
    language: str,
    region_code: str | None,
    search_query: str,
    filter_value_ids: list[int],
    hide_from_search: bool,
    page: int | None = None,
    per_page: int | None = None,
):
    query = Product.query.options(
        load_only(
            Product.id,
            Product.name,
            Product.name_ar,
            Product.name_en,
            Product.price,
            Product.sale_price,
            Product.stock_qty,
            Product.pack_size,
            Product.image_url,
            Product.category_id,
            Product.branch_id,
            Product.is_featured,
            Product.description,
            Product.short_description,
            Product.full_description,
            Product.sku,
            Product.tags,
            Product.search_keywords,
            Product.search_synonyms,
            Product.is_hidden_from_search,
            Product.is_active,
            Product.created_at,
        )
    ).filter(Product.is_active.is_(True))
    if category_id is not None:
        query = query.filter(Product.category_id == category_id)
    if hide_from_search:
        query = query.filter(Product.is_hidden_from_search.is_(False))
    if search_query:
        search_terms = _search_term_variants(search_query)
        conditions = []
        for term in search_terms:
            like_term = f'%{term}%'
            conditions.extend(
                [
                    Product.name.ilike(like_term),
                    Product.name_ar.ilike(like_term),
                    Product.description.ilike(like_term),
                    Product.sku.ilike(like_term),
                    Product.tags.ilike(like_term),
                    Product.search_keywords.ilike(like_term),
                    Product.search_synonyms.ilike(like_term),
                ]
            )
        query = query.filter(or_(*conditions))
    if filter_value_ids:
        matching_product_ids = (
            db.session.query(ProductFilterMap.product_id)
            .filter(ProductFilterMap.filter_value_id.in_(filter_value_ids))
            .group_by(ProductFilterMap.product_id)
            .having(
                func.count(distinct(ProductFilterMap.filter_value_id))
                >= len(filter_value_ids)
            )
        )
        query = query.filter(Product.id.in_(matching_product_ids))
    ordered_rows = query.order_by(Product.is_featured.desc(), Product.id.desc()).all()
    filtered_rows = [
        row
        for row in ordered_rows
        if row.visible_in_region(region_code)
        and (branch_id is None or row.is_available_for_branch(branch_id))
    ]
    if search_query:
        search_variants = _search_term_variants(search_query)
        filtered_rows.sort(
            key=lambda row: (
                _discovery_relevance_score(
                    row,
                    search_query,
                    search_variants=search_variants,
                    language=language,
                ),
                1 if bool(row.is_featured) else 0,
                row.created_at.timestamp() if row.created_at else 0,
                row.id or 0,
            ),
            reverse=True,
        )
    if page is not None and per_page is not None:
        start = max((page - 1) * per_page, 0)
        end = start + per_page
        return _ListPaginationResult(filtered_rows[start:end], len(filtered_rows))
    return filtered_rows


def serialize_discovery_products(
    products: list[Product],
    *,
    language: str = 'en',
    region_code: str | None = None,
) -> list[dict]:
    if not products:
        return []

    category_ids = {product.category_id for product in products if product.category_id is not None}
    branch_ids = {
        branch_id
        for product in products
        for branch_id in product.available_branch_ids()
        if branch_id is not None
    }
    product_ids = [product.id for product in products if product.id is not None]

    categories = {
        row.id: row.localized_name(language)
        for row in Category.query.filter(Category.id.in_(category_ids)).all()
    }
    branches = {
        row.id: row.name
        for row in Branch.query.filter(Branch.id.in_(branch_ids)).all()
    }
    rating_summaries = _fetch_rating_summaries(product_ids)

    return [
        _serialize_discovery_product(
            product,
            category_name=categories.get(product.category_id),
            branch_name=branches.get(product.branch_id),
            language=language,
            region_code=region_code,
            rating_summary=rating_summaries.get(product.id),
        )
        for product in products
    ]


def serialize_discovery_product(
    product: Product,
    *,
    language: str = 'en',
    region_code: str | None = None,
):
    return _serialize_discovery_product(
        product,
        language=language,
        region_code=region_code,
    )


def _serialize_discovery_product(
    product: Product,
    *,
    category_name: str | None = None,
    branch_name: str | None = None,
    language: str = 'en',
    region_code: str | None = None,
    rating_summary: dict | None = None,
):
    summary = rating_summary or _fetch_rating_summaries([product.id]).get(product.id, {})
    review_count = int(summary.get('review_count', 0))
    average_rating = float(summary.get('average_rating', 0))
    rating_distribution = summary.get(
        'rating_distribution',
        {str(star): 0 for star in range(1, 6)},
    )
    branch_names = {
        row.id: row.name
        for row in Branch.query.filter(
            Branch.id.in_([item.branch_id for item in product.branch_availability])
        ).all()
    } if product.branch_availability else {}
    return {
        'id': product.id,
        'name': product.localized_name(language),
        'name_en': product.name_en or product.name,
        'name_ar': product.name_ar,
        'price': float(product.effective_price(region_code) or 0),
        'sale_price': (
            float(product.effective_sale_price(region_code))
            if product.effective_sale_price(region_code) is not None
            else None
        ),
        'stock_qty': product.stock_qty,
        'pack_size': product.pack_size,
        'image_url': product.resolved_image_url,
        'primary_image_url': product.resolved_image_url,
        'images': product.resolved_images,
        'category_id': product.category_id,
        'branch_id': product.branch_id,
        'is_featured': product.is_featured,
        'description': product.description,
        'short_description': product.localized_short_description(language),
        'short_description_en': product.short_description_en or product.short_description,
        'short_description_ar': product.short_description_ar,
        'full_description': product.localized_full_description(language),
        'full_description_en': product.full_description_en or product.full_description,
        'full_description_ar': product.full_description_ar,
        'sku': product.sku,
        'tags': product.tags,
        'search_keywords': product.search_keywords,
        'search_synonyms': product.search_synonyms,
        'is_hidden_from_search': bool(product.is_hidden_from_search),
        'is_active': bool(product.is_active),
        'category_name': category_name,
        'category_name_en': category_name,
        'branch_name': branch_name,
        'branch_availability': [
            {
                'branch_id': row.branch_id,
                'branch_name': branch_names.get(row.branch_id),
                'is_available': bool(row.is_available),
            }
            for row in product.branch_availability
        ],
        'available_branch_ids': product.available_branch_ids(),
        'region_prices': [
            {
                'region_code': row.region_code,
                'currency_code': row.currency_code,
                'price': float(row.price or 0),
                'sale_price': float(row.sale_price) if row.sale_price is not None else None,
                'is_visible': bool(row.is_visible),
            }
            for row in product.region_prices
        ],
        'average_rating': round(average_rating, 2),
        'review_count': review_count,
        'rating_distribution': rating_distribution,
        'created_at': product.created_at.isoformat() if product.created_at else None,
    }


def serialize_discovery_filters(
    *,
    category_id: int | None,
    branch_id: int | None,
    search_query: str,
    language: str = 'en',
    region_code: str | None = None,
):
    available_product_ids = {
        row.id
        for row in run_discovery_product_query(
            category_id=category_id,
            branch_id=branch_id,
            language=language,
            region_code=region_code,
            search_query=search_query,
            filter_value_ids=[],
            hide_from_search=False,
            page=None,
            per_page=None,
        )
    }
    query = FilterGroup.query.filter_by(is_active=True, is_public=True)
    if category_id is not None:
        query = query.join(
            CategoryFilterGroupMap,
            CategoryFilterGroupMap.filter_group_id == FilterGroup.id,
        ).filter(CategoryFilterGroupMap.category_id == category_id)
    rows = query.order_by(FilterGroup.sort_order.asc(), FilterGroup.name.asc()).all()
    items = []
    for row in rows:
        values = (
            FilterValue.query.filter_by(group_id=row.id, is_active=True)
            .order_by(FilterValue.sort_order.asc(), FilterValue.value.asc())
            .all()
        )
        serialized_values = []
        for value in values:
            count = (
                db.session.query(func.count(ProductFilterMap.product_id))
                .filter(ProductFilterMap.filter_value_id == value.id)
                .filter(ProductFilterMap.product_id.in_(available_product_ids or {-1}))
                .scalar()
                or 0
            )
            serialized_values.append(
                {
                    'id': value.id,
                    'group_id': value.group_id,
                    'value': value.value,
                    'value_ar': value.value_ar,
                    'slug': value.slug,
                    'sort_order': value.sort_order,
                    'is_active': value.is_active,
                    'product_count': int(count),
                }
            )
        items.append(
            {
                'id': row.id,
                'name': row.name,
                'slug': row.slug,
                'filter_type': row.filter_type,
                'sort_order': row.sort_order,
                'is_active': row.is_active,
                'is_public': row.is_public,
                'values': serialized_values,
            }
        )
    return items


def _serialize_search_term(row: SearchTerm):
    return {
        'id': row.id,
        'term': row.term,
        'term_type': row.term_type,
        'synonyms': row.synonyms,
        'linked_category_id': row.linked_category_id,
        'linked_product_id': row.linked_product_id,
        'sort_order': row.sort_order,
        'is_active': row.is_active,
    }


def _parse_filter_value_ids(raw_value: str | None) -> list[int]:
    if raw_value is None or not raw_value.strip():
        return []
    values = []
    for chunk in raw_value.split(','):
        token = chunk.strip()
        if not token:
            continue
        try:
            values.append(int(token))
        except ValueError:
            return []
    return list(dict.fromkeys(values))


def _search_term_variants(search_query: str) -> list[str]:
    normalized = search_query.strip().lower()
    if not normalized:
        return []
    variants = {normalized}
    matching_terms = (
        SearchTerm.query.filter_by(is_active=True)
        .filter(
            or_(
                func.lower(SearchTerm.term) == normalized,
                SearchTerm.term.ilike(f'%{normalized}%'),
                SearchTerm.synonyms.ilike(f'%{normalized}%'),
            )
        )
        .all()
    )
    for row in matching_terms:
        variants.add((row.term or '').strip().lower())
        for synonym in (row.synonyms or '').split(','):
            cleaned = synonym.strip().lower()
            if cleaned:
                variants.add(cleaned)
    return [value for value in variants if value]


def _discovery_relevance_score(
    product: Product,
    search_query: str,
    *,
    search_variants: list[str] | None = None,
    language: str,
) -> int:
    normalized_query = (search_query or '').strip().lower()
    if not normalized_query:
        return 0

    searchable_values = [
        product.localized_name(language),
        product.name_en or product.name,
        product.name_ar,
        product.short_description_en or product.short_description,
        product.short_description_ar,
        product.full_description_en or product.full_description,
        product.full_description_ar,
        product.description,
        product.sku,
        product.tags,
        product.search_keywords,
        product.search_synonyms,
    ]
    score = 0
    for value in searchable_values:
        text = (value or '').strip().lower()
        if not text:
            continue
        if text == normalized_query:
            score += 120
        elif text.startswith(normalized_query):
            score += 80
        elif f' {normalized_query}' in text or text.endswith(normalized_query):
            score += 45
        elif normalized_query in text:
            score += 20

    for synonym in (search_variants or _search_term_variants(normalized_query)):
        if synonym == normalized_query:
            continue
        text = (product.search_keywords or '').strip().lower()
        tags = (product.tags or '').strip().lower()
        if synonym and (synonym in text or synonym in tags):
            score += 10

    return score


def _fetch_rating_summaries(product_ids: list[int]) -> dict[int, dict]:
    if not product_ids:
        return {}

    rows = (
        db.session.query(
            Review.product_id,
            Review.rating,
            func.count(Review.id),
        )
        .filter(
            Review.product_id.in_(product_ids),
            Review.moderation_status == 'approved',
        )
        .group_by(Review.product_id, Review.rating)
        .all()
    )

    summaries = {
        product_id: {
            'review_count': 0,
            'average_rating': 0.0,
            'rating_distribution': {str(star): 0 for star in range(1, 6)},
            '_rating_total': 0,
        }
        for product_id in product_ids
    }

    for product_id, rating, count in rows:
        entry = summaries.setdefault(
            product_id,
            {
                'review_count': 0,
                'average_rating': 0.0,
                'rating_distribution': {str(star): 0 for star in range(1, 6)},
                '_rating_total': 0,
            },
        )
        count_value = int(count or 0)
        entry['review_count'] += count_value
        entry['_rating_total'] += int(rating or 0) * count_value
        entry['rating_distribution'][str(int(rating or 0))] = count_value

    for entry in summaries.values():
        review_count = int(entry['review_count'])
        entry['average_rating'] = (
            entry['_rating_total'] / review_count if review_count else 0.0
        )
        entry.pop('_rating_total', None)

    return summaries
