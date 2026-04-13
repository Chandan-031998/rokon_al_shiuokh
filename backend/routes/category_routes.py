from flask import Blueprint
from sqlalchemy.exc import SQLAlchemyError

from models.category import Category
from routes.response_utils import empty_array_response
from services.catalog_seed import ensure_starter_catalog_data
from services.db_compat import load_only_existing
from services.catalog_data import icon_key_for_category
from utils.api import api_response


category_bp = Blueprint('categories', __name__)


@category_bp.get('/')
def list_categories():
    try:
        ensure_starter_catalog_data()
        query = Category.query
        option = load_only_existing(
            Category,
            'categories',
            ['id', 'name', 'name_ar', 'image_url', 'sort_order', 'is_active'],
        )
        if option is not None:
            query = query.options(option)
        rows = query.filter_by(is_active=True).order_by(Category.sort_order.asc(), Category.id.asc()).all()
    except SQLAlchemyError:
        return empty_array_response('Categories')

    return api_response([
        {
            'id': row.id,
            'name': row.name,
            'name_ar': row.name_ar,
            'image_url': row.image_url,
            'icon_key': icon_key_for_category(row.name),
        }
        for row in rows
    ])
