from flask import Blueprint, request
from sqlalchemy import or_
from sqlalchemy.exc import SQLAlchemyError

from models.product import Product
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import column_exists, load_only_existing
from utils.api import api_response


product_bp = Blueprint('products', __name__)


def _serialize_product(product: Product):
    has_pack_size = column_exists('products', 'pack_size')
    price_value = float(product.price or 0)
    return {
        'id': product.id,
        'name': product.name,
        'name_ar': product.name_ar,
        'price': price_value,
        'stock_qty': product.stock_qty,
        'pack_size': product.pack_size if has_pack_size else None,
        'image_url': product.resolved_image_url,
        'category_id': product.category_id,
        'branch_id': product.branch_id,
        'is_featured': product.is_featured,
        'description': product.description,
        'sku': product.sku,
    }


@product_bp.get('/')
def list_products():
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    search_query = (request.args.get('q') or '').strip()
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
        ],
    )
    if option is not None:
        query = query.options(option)
    query = query.filter_by(is_active=True)

    try:
        ensure_starter_catalog_data()
        if category_id:
            query = query.filter_by(category_id=category_id)
        if branch_id:
            query = query.filter_by(branch_id=branch_id)
        if search_query:
            like_term = f'%{search_query}%'
            query = query.filter(
                or_(
                    Product.name.ilike(like_term),
                    Product.name_ar.ilike(like_term),
                    Product.description.ilike(like_term),
                    Product.sku.ilike(like_term),
                )
            )

        rows = query.order_by(Product.id.desc()).all()
    except SQLAlchemyError:
        return empty_array_response('Products')

    return api_response([_serialize_product(p) for p in rows])


@product_bp.get('/featured')
def featured_products():
    try:
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
            ],
        )
        if option is not None:
            query = query.options(option)
        rows = query.filter_by(is_active=True, is_featured=True).order_by(Product.id.desc()).limit(12).all()
        if not rows:
            rows = query.filter_by(is_active=True).order_by(Product.id.desc()).limit(12).all()
    except SQLAlchemyError:
        return empty_array_response('Featured products')

    return api_response([_serialize_product(p) for p in rows])
