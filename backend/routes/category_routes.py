from flask import Blueprint, request
from sqlalchemy.exc import SQLAlchemyError

from models.category import Category
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import load_only_existing
from services.runtime_cache import runtime_ttl_cache
from services.catalog_data import icon_key_for_category
from utils.api import items_response, parse_pagination_args, pagination_payload


category_bp = Blueprint('categories', __name__)


@category_bp.get('/')
def list_categories():
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    language = (request.args.get('language') or 'en').strip().lower()
    cache_key = f'categories:page={page}:per_page={per_page}:language={language}'

    try:
        def build_payload():
            ensure_starter_catalog_data()
            query = Category.query
            option = load_only_existing(
                Category,
                'categories',
                [
                    'id',
                    'name',
                    'name_en',
                    'name_ar',
                    'image_url',
                    'icon_key',
                    'sort_order',
                    'is_active',
                ],
            )
            if option is not None:
                query = query.options(option)
            base_query = query.filter_by(is_active=True)
            total = base_query.count()
            rows = (
                base_query.order_by(Category.sort_order.asc(), Category.id.asc())
                .offset((page - 1) * per_page)
                .limit(per_page)
                .all()
            )
            return {
                'items': [
                    {
                        'id': row.id,
                        'name': row.localized_name(language),
                        'name_en': row.name_en or row.name,
                        'name_ar': row.name_ar,
                        'image_url': row.image_url,
                        'icon_key': row.icon_key or icon_key_for_category(row.name),
                    }
                    for row in rows
                ],
                'pagination': pagination_payload(
                    page=page,
                    per_page=per_page,
                    total=total,
                ),
            }

        payload = runtime_ttl_cache.get_or_set(cache_key, 120, build_payload)
    except SQLAlchemyError:
        return empty_array_response('Categories')

    return items_response(payload['items'], pagination=payload['pagination'])
