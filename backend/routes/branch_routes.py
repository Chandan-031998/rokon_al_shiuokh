from flask import Blueprint
from sqlalchemy.exc import SQLAlchemyError

from models.branch import Branch
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import column_exists, load_only_existing
from services.runtime_cache import runtime_ttl_cache
from utils.api import items_response, parse_pagination_args, pagination_payload

branch_bp = Blueprint('branches', __name__)


@branch_bp.get('/')
def list_branches():
    page, per_page = parse_pagination_args(default_per_page=24, max_per_page=60)
    cache_key = f'branches:page={page}:per_page={per_page}'

    try:
        has_pickup_available = column_exists('branches', 'pickup_available')
        has_delivery_available = column_exists('branches', 'delivery_available')
        has_delivery_coverage = column_exists('branches', 'delivery_coverage')

        def build_payload():
            ensure_starter_catalog_data()
            query = Branch.query
            option = load_only_existing(
                Branch,
                'branches',
                [
                    'id',
                    'name',
                    'city',
                    'address',
                    'phone',
                    'is_active',
                    'pickup_available',
                    'delivery_available',
                    'delivery_coverage',
                ],
            )
            if option is not None:
                query = query.options(option)
            base_query = query.filter_by(is_active=True)
            total = base_query.count()
            rows = (
                base_query.order_by(Branch.id.asc())
                .offset((page - 1) * per_page)
                .limit(per_page)
                .all()
            )
            return {
                'items': [
                    {
                        'id': b.id,
                        'name': b.name,
                        'city': b.city,
                        'address': b.address,
                        'phone': b.phone,
                        'pickup_available': b.pickup_available if has_pickup_available else True,
                        'delivery_available': b.delivery_available if has_delivery_available else True,
                        'delivery_coverage': b.delivery_coverage if has_delivery_coverage else None,
                    }
                    for b in rows
                ],
                'pagination': pagination_payload(
                    page=page,
                    per_page=per_page,
                    total=total,
                ),
            }

        payload = runtime_ttl_cache.get_or_set(cache_key, 120, build_payload)
    except SQLAlchemyError:
        return empty_array_response('Branches')

    return items_response(payload['items'], pagination=payload['pagination'])
