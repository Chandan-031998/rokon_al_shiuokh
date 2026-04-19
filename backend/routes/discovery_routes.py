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


@discovery_bp.get('/search')
def search_products():
    search_query = (request.args.get('q') or '').strip()
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    filter_value_ids = _parse_filter_value_ids(request.args.get('filter_value_ids'))
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    rows = run_discovery_product_query(
        category_id=category_id,
        branch_id=branch_id,
        search_query=search_query,
        filter_value_ids=filter_value_ids,
        hide_from_search=True,
        page=page,
        per_page=per_page,
    )
    return success_response(
        query=search_query,
        items=serialize_discovery_products(rows.items),
        pagination=pagination_payload(page=page, per_page=per_page, total=rows.total),
        filters=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
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
    search_query = (request.args.get('q') or '').strip()
    return success_response(
        items=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
        )
    )


@discovery_bp.get('/categories/<int:category_id>/products')
def list_category_products(category_id: int):
    branch_id = request.args.get('branch_id', type=int)
    search_query = (request.args.get('q') or '').strip()
    filter_value_ids = _parse_filter_value_ids(request.args.get('filter_value_ids'))
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    rows = run_discovery_product_query(
        category_id=category_id,
        branch_id=branch_id,
        search_query=search_query,
        filter_value_ids=filter_value_ids,
        hide_from_search=False,
        page=page,
        per_page=per_page,
    )
    return success_response(
        items=serialize_discovery_products(rows.items),
        pagination=pagination_payload(page=page, per_page=per_page, total=rows.total),
        filters=serialize_discovery_filters(
            category_id=category_id,
            branch_id=branch_id,
            search_query=search_query,
        ),
    )


def run_discovery_product_query(
    *,
    category_id: int | None,
    branch_id: int | None,
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
        )
    ).filter(Product.is_active.is_(True))
    if category_id is not None:
        query = query.filter(Product.category_id == category_id)
    if branch_id is not None:
        query = query.filter(Product.branch_id == branch_id)
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
    ordered = query.order_by(Product.is_featured.desc(), Product.id.desc())
    if page is not None and per_page is not None:
        return ordered.paginate(page=page, per_page=per_page, error_out=False)
    return ordered.all()


def serialize_discovery_products(products: list[Product]) -> list[dict]:
    if not products:
        return []

    category_ids = {product.category_id for product in products if product.category_id is not None}
    branch_ids = {product.branch_id for product in products if product.branch_id is not None}
    product_ids = [product.id for product in products if product.id is not None]

    categories = {
        row.id: row.name
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
            rating_summary=rating_summaries.get(product.id),
        )
        for product in products
    ]


def serialize_discovery_product(product: Product):
    return _serialize_discovery_product(product)


def _serialize_discovery_product(
    product: Product,
    *,
    category_name: str | None = None,
    branch_name: str | None = None,
    rating_summary: dict | None = None,
):
    summary = rating_summary or _fetch_rating_summaries([product.id]).get(product.id, {})
    review_count = int(summary.get('review_count', 0))
    average_rating = float(summary.get('average_rating', 0))
    rating_distribution = summary.get(
        'rating_distribution',
        {str(star): 0 for star in range(1, 6)},
    )
    return {
        'id': product.id,
        'name': product.name,
        'name_ar': product.name_ar,
        'price': float(product.price or 0),
        'sale_price': float(product.sale_price) if product.sale_price is not None else None,
        'stock_qty': product.stock_qty,
        'pack_size': product.pack_size,
        'image_url': product.resolved_image_url,
        'category_id': product.category_id,
        'branch_id': product.branch_id,
        'is_featured': product.is_featured,
        'description': product.description,
        'short_description': product.short_description,
        'full_description': product.full_description,
        'sku': product.sku,
        'tags': product.tags,
        'search_keywords': product.search_keywords,
        'search_synonyms': product.search_synonyms,
        'is_hidden_from_search': bool(product.is_hidden_from_search),
        'is_active': bool(product.is_active),
        'category_name': category_name,
        'branch_name': branch_name,
        'average_rating': round(average_rating, 2),
        'review_count': review_count,
        'rating_distribution': rating_distribution,
    }


def serialize_discovery_filters(
    *,
    category_id: int | None,
    branch_id: int | None,
    search_query: str,
):
    available_product_ids = {
        row.id
        for row in run_discovery_product_query(
            category_id=category_id,
            branch_id=branch_id,
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
