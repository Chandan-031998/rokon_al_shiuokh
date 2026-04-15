from flask import Blueprint
from sqlalchemy.exc import SQLAlchemyError

from models.branch import Branch
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import column_exists, load_only_existing
from utils.api import api_response

branch_bp = Blueprint('branches', __name__)


@branch_bp.get('/')
def list_branches():
    try:
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
        rows = query.filter_by(is_active=True).order_by(Branch.id.asc()).all()
    except SQLAlchemyError:
        return empty_array_response('Branches')

    has_pickup_available = column_exists('branches', 'pickup_available')
    has_delivery_available = column_exists('branches', 'delivery_available')
    has_delivery_coverage = column_exists('branches', 'delivery_coverage')

    return api_response(
        [
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
        cache_seconds=300,
    )
