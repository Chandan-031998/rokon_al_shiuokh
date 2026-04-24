from flask import Blueprint, request
from sqlalchemy import or_
from sqlalchemy.exc import SQLAlchemyError

from models.branch import Branch
from models.product import Product
from routes.discovery_routes import run_discovery_product_query, serialize_discovery_product, serialize_discovery_products
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import load_only_existing
from services.runtime_cache import runtime_ttl_cache
from utils.api import error_response, items_response, pagination_payload, parse_pagination_args, success_response


product_bp = Blueprint('products', __name__)


def _serialize_product(product: Product):
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    return serialize_discovery_product(
        product,
        language=language,
        region_code=region_code,
    )


@product_bp.get('/')
def list_products():
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    search_query = (request.args.get('q') or '').strip()
    filter_value_ids = _parse_filter_value_ids(request.args.get('filter_value_ids'))
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)

    try:
        ensure_starter_catalog_data()
        rows = run_discovery_product_query(
            category_id=category_id,
            branch_id=branch_id,
            language=language,
            region_code=region_code,
            search_query=search_query,
            filter_value_ids=filter_value_ids,
            hide_from_search=bool(search_query),
            page=page,
            per_page=per_page,
        )
    except SQLAlchemyError:
        return empty_array_response('Products')

    return items_response(
        serialize_discovery_products(
            rows.items,
            language=language,
            region_code=region_code,
        ),
        pagination=pagination_payload(page=page, per_page=per_page, total=rows.total),
    )


@product_bp.get('/featured')
def featured_products():
    page, per_page = parse_pagination_args(default_per_page=12, max_per_page=24)
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    cache_key = (
        f'featured-products:page={page}:per_page={per_page}:'
        f'language={language}:region={region_code or "all"}'
    )

    try:
        def build_payload():
            ensure_starter_catalog_data()
            query = Product.query
            option = load_only_existing(
                Product,
                'products',
                [
                    'id',
                    'name',
                    'name_ar',
                    'price',
                    'stock_qty',
                    'pack_size',
                    'image_url',
                    'category_id',
                    'branch_id',
                    'is_featured',
                    'is_active',
                    'description',
                    'sku',
                    'sale_price',
                    'short_description',
                    'full_description',
                    'tags',
                    'search_keywords',
                    'search_synonyms',
                    'is_hidden_from_search',
                ],
            )
            if option is not None:
                query = query.options(option)
            featured_query = query.filter_by(is_active=True, is_featured=True)
            total = featured_query.count()
            rows = (
                featured_query.order_by(Product.id.desc())
                .offset((page - 1) * per_page)
                .limit(per_page)
                .all()
            )
            if not rows:
                fallback_query = query.filter_by(is_active=True)
                total = fallback_query.count()
                rows = (
                    fallback_query.order_by(Product.id.desc())
                    .offset((page - 1) * per_page)
                    .limit(per_page)
                    .all()
                )
            visible_rows = [
                row for row in rows if row.visible_in_region(region_code)
            ]
            return {
                'items': serialize_discovery_products(
                    visible_rows,
                    language=language,
                    region_code=region_code,
                ),
                'pagination': pagination_payload(
                    page=page,
                    per_page=per_page,
                    total=len(visible_rows) if rows else total,
                ),
            }

        payload = runtime_ttl_cache.get_or_set(cache_key, 120, build_payload)
    except SQLAlchemyError:
        return empty_array_response('Featured products')

    return items_response(payload['items'], pagination=payload['pagination'])


@product_bp.get('/<int:product_id>')
def get_product_detail(product_id: int):
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    try:
        ensure_starter_catalog_data()
        product = Product.query.filter_by(id=product_id, is_active=True).first()
        if product is None:
            return error_response('Product not found.', status=404)

        related_query = Product.query.filter(
            Product.is_active.is_(True),
            Product.category_id == product.category_id,
            Product.id != product.id,
        )
        if product.branch_id is not None:
            related_query = related_query.filter(
                or_(Product.branch_id == product.branch_id, Product.branch_id.is_(None))
            )

        related_products = (
            related_query.order_by(Product.is_featured.desc(), Product.id.desc())
            .all()
        )
        active_branches = Branch.query.filter_by(is_active=True).order_by(Branch.name.asc()).all()
    except SQLAlchemyError:
        return error_response('Failed to load product details.', status=500)

    return success_response(
        product=_serialize_product(product),
        related_products=[
            serialize_discovery_product(
                row,
                language=language,
                region_code=region_code,
            )
            for row in related_products
            if row.visible_in_region(region_code)
        ][:4],
        available_branches=[
            _serialize_branch_availability(branch, product) for branch in active_branches
        ],
    )


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


def _serialize_branch_availability(branch: Branch, product: Product) -> dict:
    available_for_branch = product.is_available_for_branch(branch.id)
    region_settings = [
        {
            'region_code': row.region_code,
            'currency_code': row.currency_code,
            'is_visible': bool(row.is_visible),
            'pickup_available': bool(row.pickup_available),
            'delivery_available': bool(row.delivery_available),
            'delivery_coverage': row.delivery_coverage,
        }
        for row in branch.region_settings
    ]
    return {
        'id': branch.id,
        'name': branch.name,
        'region_code': branch.region_code,
        'default_currency_code': branch.default_currency_code,
        'city': branch.city,
        'address': branch.address,
        'phone': branch.phone,
        'map_link': branch.map_link,
        'is_active': bool(branch.is_active),
        'pickup_available': bool(branch.pickup_available),
        'delivery_available': bool(branch.delivery_available),
        'delivery_coverage': branch.delivery_coverage,
        'region_settings': region_settings,
        'product_available': available_for_branch and bool(branch.is_active),
    }
