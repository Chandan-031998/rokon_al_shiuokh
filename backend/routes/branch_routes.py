from flask import Blueprint, request
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
    region_code = (request.args.get('region_code') or '').strip().lower() or None
    cache_key = (
        f'branches:page={page}:per_page={per_page}:region={region_code or "all"}'
    )

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
            if region_code:
                base_query = base_query.filter(
                    Branch.region_code.is_(None) | (Branch.region_code == region_code)
                )
            total = base_query.count()
            rows = (
                base_query.order_by(Branch.id.asc())
                .offset((page - 1) * per_page)
                .limit(per_page)
                .all()
            )
            return {
                'items': [
                    _serialize_branch(
                        b,
                        region_code=region_code,
                        has_pickup_available=has_pickup_available,
                        has_delivery_available=has_delivery_available,
                        has_delivery_coverage=has_delivery_coverage,
                    )
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


def _serialize_branch(
    branch: Branch,
    *,
    region_code: str | None,
    has_pickup_available: bool,
    has_delivery_available: bool,
    has_delivery_coverage: bool,
) -> dict:
    region_settings = []
    active_region = None
    for row in branch.region_settings or []:
        serialized = {
            'region_code': row.region_code,
            'currency_code': row.currency_code,
            'is_visible': bool(row.is_visible),
            'pickup_available': bool(row.pickup_available),
            'delivery_available': bool(row.delivery_available),
            'delivery_coverage': row.delivery_coverage,
        }
        region_settings.append(serialized)
        if region_code and row.region_code == region_code:
            active_region = serialized

    pickup_available = branch.pickup_available if has_pickup_available else True
    delivery_available = branch.delivery_available if has_delivery_available else True
    delivery_coverage = branch.delivery_coverage if has_delivery_coverage else None
    if active_region is not None:
        pickup_available = active_region['pickup_available']
        delivery_available = active_region['delivery_available']
        delivery_coverage = active_region['delivery_coverage']

    return {
        'id': branch.id,
        'name': branch.name,
        'region_code': branch.region_code,
        'default_currency_code': branch.default_currency_code,
        'city': branch.city,
        'address': branch.address,
        'phone': branch.phone,
        'pickup_available': pickup_available,
        'delivery_available': delivery_available,
        'delivery_coverage': delivery_coverage,
        'region_settings': region_settings,
    }
