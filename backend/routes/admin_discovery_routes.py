from __future__ import annotations

import re

from flask import Blueprint, request
from sqlalchemy import func, or_

from extensions import db
from models.branch import Branch
from models.category import Category
from models.category_filter_group_map import CategoryFilterGroupMap
from models.filter_group import FilterGroup
from models.filter_value import FilterValue
from models.product import Product
from models.product_filter_map import ProductFilterMap
from models.search_term import SearchTerm
from utils.api import error_response, items_response, success_response
from utils.auth import admin_required
from utils.validators import ValidationError, get_json_body, optional_string, required_string


admin_discovery_bp = Blueprint('admin_discovery', __name__)

ALLOWED_SEARCH_TERM_TYPES = {'popular', 'featured'}
ALLOWED_FILTER_TYPES = {'multi_select', 'single_select', 'swatch', 'bucket'}


@admin_discovery_bp.get('/products')
@admin_required
def list_discovery_products():
    search = (request.args.get('search') or '').strip()
    hidden = (request.args.get('hidden') or '').strip().lower()
    query = Product.query
    if search:
        like_term = f'%{search}%'
        query = query.filter(
            or_(
                Product.name.ilike(like_term),
                Product.sku.ilike(like_term),
                Product.tags.ilike(like_term),
                Product.search_keywords.ilike(like_term),
                Product.search_synonyms.ilike(like_term),
            )
        )
    if hidden in {'true', 'false'}:
        query = query.filter(Product.is_hidden_from_search.is_(hidden == 'true'))
    rows = query.order_by(Product.name.asc()).all()
    return items_response([_serialize_discovery_product(row) for row in rows], total=len(rows))


@admin_discovery_bp.patch('/products/<int:product_id>')
@admin_required
def update_discovery_product(product_id: int):
    row = Product.query.filter_by(id=product_id).first()
    if row is None:
        return error_response('Product not found.', status=404)
    try:
        data = get_json_body()
        if 'tags' in data:
            row.tags = optional_string(data, 'tags')
        if 'search_keywords' in data:
            row.search_keywords = optional_string(data, 'search_keywords')
        if 'search_synonyms' in data:
            row.search_synonyms = optional_string(data, 'search_synonyms')
        if 'is_hidden_from_search' in data:
            row.is_hidden_from_search = _bool_field(data.get('is_hidden_from_search'))
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(product=_serialize_discovery_product(row))


@admin_discovery_bp.get('/search-terms')
@admin_required
def list_search_terms():
    rows = SearchTerm.query.order_by(SearchTerm.sort_order.asc(), SearchTerm.term.asc()).all()
    return items_response([_serialize_search_term(row) for row in rows], total=len(rows))


@admin_discovery_bp.post('/search-terms')
@admin_required
def create_search_term():
    try:
        payload = _parse_search_term_payload()
        row = SearchTerm(**payload)
        db.session.add(row)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(status=201, term=_serialize_search_term(row))


@admin_discovery_bp.patch('/search-terms/<int:term_id>')
@admin_required
def update_search_term(term_id: int):
    row = SearchTerm.query.filter_by(id=term_id).first()
    if row is None:
        return error_response('Search term not found.', status=404)
    try:
        payload = _parse_search_term_payload(current_id=term_id, partial=True)
        for key, value in payload.items():
            setattr(row, key, value)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(term=_serialize_search_term(row))


@admin_discovery_bp.delete('/search-terms/<int:term_id>')
@admin_required
def delete_search_term(term_id: int):
    row = SearchTerm.query.filter_by(id=term_id).first()
    if row is None:
        return error_response('Search term not found.', status=404)
    db.session.delete(row)
    db.session.commit()
    return success_response(message='Search term deleted.')


@admin_discovery_bp.get('/filter-groups')
@admin_required
def list_filter_groups():
    rows = FilterGroup.query.order_by(FilterGroup.sort_order.asc(), FilterGroup.name.asc()).all()
    return items_response([_serialize_filter_group(row) for row in rows], total=len(rows))


@admin_discovery_bp.post('/filter-groups')
@admin_required
def create_filter_group():
    try:
        payload, category_ids = _parse_filter_group_payload()
        row = FilterGroup(**payload)
        db.session.add(row)
        db.session.flush()
        _replace_group_categories(row.id, category_ids)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(status=201, group=_serialize_filter_group(row))


@admin_discovery_bp.patch('/filter-groups/<int:group_id>')
@admin_required
def update_filter_group(group_id: int):
    row = FilterGroup.query.filter_by(id=group_id).first()
    if row is None:
        return error_response('Filter group not found.', status=404)
    try:
        payload, category_ids = _parse_filter_group_payload(current_id=group_id, partial=True)
        for key, value in payload.items():
            setattr(row, key, value)
        if category_ids is not None:
            _replace_group_categories(group_id, category_ids)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(group=_serialize_filter_group(row))


@admin_discovery_bp.delete('/filter-groups/<int:group_id>')
@admin_required
def delete_filter_group(group_id: int):
    row = FilterGroup.query.filter_by(id=group_id).first()
    if row is None:
        return error_response('Filter group not found.', status=404)
    db.session.delete(row)
    db.session.commit()
    return success_response(message='Filter group deleted.')


@admin_discovery_bp.get('/filter-values')
@admin_required
def list_filter_values():
    group_id = request.args.get('group_id', type=int)
    query = FilterValue.query
    if group_id is not None:
        query = query.filter(FilterValue.group_id == group_id)
    rows = query.order_by(FilterValue.sort_order.asc(), FilterValue.value.asc()).all()
    return items_response([_serialize_filter_value(row) for row in rows], total=len(rows))


@admin_discovery_bp.post('/filter-values')
@admin_required
def create_filter_value():
    try:
        payload, product_ids = _parse_filter_value_payload()
        row = FilterValue(**payload)
        db.session.add(row)
        db.session.flush()
        _replace_value_products(row.id, product_ids)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(status=201, value=_serialize_filter_value(row))


@admin_discovery_bp.patch('/filter-values/<int:value_id>')
@admin_required
def update_filter_value(value_id: int):
    row = FilterValue.query.filter_by(id=value_id).first()
    if row is None:
        return error_response('Filter value not found.', status=404)
    try:
        payload, product_ids = _parse_filter_value_payload(partial=True)
        for key, value in payload.items():
            setattr(row, key, value)
        if product_ids is not None:
            _replace_value_products(value_id, product_ids)
        db.session.commit()
    except ValidationError as exc:
        db.session.rollback()
        return error_response(str(exc), status=400)
    return success_response(value=_serialize_filter_value(row))


@admin_discovery_bp.delete('/filter-values/<int:value_id>')
@admin_required
def delete_filter_value(value_id: int):
    row = FilterValue.query.filter_by(id=value_id).first()
    if row is None:
        return error_response('Filter value not found.', status=404)
    db.session.delete(row)
    db.session.commit()
    return success_response(message='Filter value deleted.')


def _parse_search_term_payload(*, current_id: int | None = None, partial: bool = False):
    data = get_json_body()
    payload = {}
    if not partial or 'term' in data:
        term = required_string(data, 'term', label='Term')
        existing = SearchTerm.query.filter(func.lower(SearchTerm.term) == term.lower()).first()
        if existing and existing.id != current_id:
            raise ValidationError('Search term already exists.')
        payload['term'] = term
    if not partial or 'term_type' in data:
        term_type = required_string(data, 'term_type', label='Term type', lower=True)
        if term_type not in ALLOWED_SEARCH_TERM_TYPES:
            raise ValidationError('Term type is invalid.')
        payload['term_type'] = term_type
    if not partial or 'synonyms' in data:
        payload['synonyms'] = optional_string(data, 'synonyms')
    if not partial or 'linked_category_id' in data:
        payload['linked_category_id'] = _existing_category_id(data.get('linked_category_id'))
    if not partial or 'linked_product_id' in data:
        payload['linked_product_id'] = _existing_product_id(data.get('linked_product_id'))
    if not partial or 'sort_order' in data:
        payload['sort_order'] = _coerce_int(data.get('sort_order', 0), label='Sort order')
    if not partial or 'is_active' in data:
        payload['is_active'] = _bool_field(data.get('is_active', True))
    return payload


def _parse_filter_group_payload(*, current_id: int | None = None, partial: bool = False):
    data = get_json_body()
    payload = {}
    category_ids = None
    if not partial or 'name' in data:
        payload['name'] = required_string(data, 'name', label='Name')
    if not partial or 'slug' in data or 'name' in data:
        source = optional_string(data, 'slug') or payload.get('name') or data.get('name')
        slug = _slugify(source)
        existing = FilterGroup.query.filter(func.lower(FilterGroup.slug) == slug.lower()).first()
        if existing and existing.id != current_id:
            raise ValidationError('Filter group slug already exists.')
        payload['slug'] = slug
    if not partial or 'filter_type' in data:
        filter_type = required_string(data, 'filter_type', label='Filter type', lower=True)
        if filter_type not in ALLOWED_FILTER_TYPES:
            raise ValidationError('Filter type is invalid.')
        payload['filter_type'] = filter_type
    if not partial or 'sort_order' in data:
        payload['sort_order'] = _coerce_int(data.get('sort_order', 0), label='Sort order')
    if not partial or 'is_active' in data:
        payload['is_active'] = _bool_field(data.get('is_active', True))
    if not partial or 'is_public' in data:
        payload['is_public'] = _bool_field(data.get('is_public', True))
    if 'category_ids' in data:
        category_ids = _integer_list(data.get('category_ids'), label='Category IDs')
        for category_id in category_ids:
            if not Category.query.filter_by(id=category_id).first():
                raise ValidationError('A selected category was not found.')
    elif not partial:
        category_ids = []
    return payload, category_ids


def _parse_filter_value_payload(*, partial: bool = False):
    data = get_json_body()
    payload = {}
    product_ids = None
    if not partial or 'group_id' in data:
        payload['group_id'] = _existing_group_id(data.get('group_id'))
    if not partial or 'value' in data:
        payload['value'] = required_string(data, 'value', label='Value')
    if not partial or 'value_ar' in data:
        payload['value_ar'] = optional_string(data, 'value_ar')
    if not partial or 'slug' in data or 'value' in data:
        source = optional_string(data, 'slug') or payload.get('value') or data.get('value')
        payload['slug'] = _slugify(source)
    if not partial or 'sort_order' in data:
        payload['sort_order'] = _coerce_int(data.get('sort_order', 0), label='Sort order')
    if not partial or 'is_active' in data:
        payload['is_active'] = _bool_field(data.get('is_active', True))
    if 'product_ids' in data:
        product_ids = _integer_list(data.get('product_ids'), label='Product IDs')
        for product_id in product_ids:
            if not Product.query.filter_by(id=product_id).first():
                raise ValidationError('A selected product was not found.')
    elif not partial:
        product_ids = []
    return payload, product_ids


def _replace_group_categories(group_id: int, category_ids: list[int]):
    CategoryFilterGroupMap.query.filter_by(filter_group_id=group_id).delete()
    for category_id in category_ids:
        db.session.add(CategoryFilterGroupMap(category_id=category_id, filter_group_id=group_id))


def _replace_value_products(value_id: int, product_ids: list[int]):
    ProductFilterMap.query.filter_by(filter_value_id=value_id).delete()
    for product_id in product_ids:
        db.session.add(ProductFilterMap(product_id=product_id, filter_value_id=value_id))


def _serialize_discovery_product(row: Product):
    category = Category.query.filter_by(id=row.category_id).first()
    branch = Branch.query.filter_by(id=row.branch_id).first() if row.branch_id else None
    assigned_value_ids = [
        mapping.filter_value_id
        for mapping in ProductFilterMap.query.filter_by(product_id=row.id).all()
    ]
    return {
        'id': row.id,
        'name': row.name,
        'sku': row.sku,
        'category_id': row.category_id,
        'category_name': category.name if category else None,
        'branch_id': row.branch_id,
        'branch_name': branch.name if branch else None,
        'tags': row.tags,
        'search_keywords': row.search_keywords,
        'search_synonyms': row.search_synonyms,
        'is_hidden_from_search': row.is_hidden_from_search,
        'assigned_filter_value_ids': assigned_value_ids,
    }


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


def _serialize_filter_group(row: FilterGroup):
    category_ids = [
        mapping.category_id
        for mapping in CategoryFilterGroupMap.query.filter_by(filter_group_id=row.id).all()
    ]
    value_count = FilterValue.query.filter_by(group_id=row.id).count()
    return {
        'id': row.id,
        'name': row.name,
        'slug': row.slug,
        'filter_type': row.filter_type,
        'sort_order': row.sort_order,
        'is_active': row.is_active,
        'is_public': row.is_public,
        'category_ids': category_ids,
        'value_count': value_count,
    }


def _serialize_filter_value(row: FilterValue):
    product_ids = [
        mapping.product_id
        for mapping in ProductFilterMap.query.filter_by(filter_value_id=row.id).all()
    ]
    return {
        'id': row.id,
        'group_id': row.group_id,
        'value': row.value,
        'value_ar': row.value_ar,
        'slug': row.slug,
        'sort_order': row.sort_order,
        'is_active': row.is_active,
        'product_ids': product_ids,
        'product_count': len(product_ids),
    }


def _slugify(value) -> str:
    normalized = re.sub(r'[^a-z0-9]+', '-', str(value or '').strip().lower()).strip('-')
    if not normalized:
        raise ValidationError('A valid slug or name is required.')
    return normalized


def _coerce_int(value, *, label: str) -> int:
    try:
        resolved = int(value)
    except (TypeError, ValueError):
        raise ValidationError(f'{label} must be an integer.') from None
    if resolved < 0:
        raise ValidationError(f'{label} must be zero or greater.')
    return resolved


def _bool_field(value) -> bool:
    if isinstance(value, bool):
        return value
    normalized = str(value).strip().lower()
    if normalized in {'true', '1', 'yes', 'y'}:
        return True
    if normalized in {'false', '0', 'no', 'n'}:
        return False
    raise ValidationError('Boolean field value is invalid.')


def _existing_category_id(value):
    if value in (None, ''):
        return None
    category_id = _coerce_int(value, label='Category')
    if not Category.query.filter_by(id=category_id).first():
        raise ValidationError('Selected category not found.')
    return category_id


def _existing_product_id(value):
    if value in (None, ''):
        return None
    product_id = _coerce_int(value, label='Product')
    if not Product.query.filter_by(id=product_id).first():
        raise ValidationError('Selected product not found.')
    return product_id


def _existing_group_id(value):
    group_id = _coerce_int(value, label='Filter group')
    if not FilterGroup.query.filter_by(id=group_id).first():
        raise ValidationError('Selected filter group not found.')
    return group_id


def _integer_list(value, *, label: str) -> list[int]:
    if value in (None, ''):
        return []
    if not isinstance(value, list):
        raise ValidationError(f'{label} must be a list of integers.')
    resolved = []
    for item in value:
        resolved.append(_coerce_int(item, label=label))
    return list(dict.fromkeys(resolved))
