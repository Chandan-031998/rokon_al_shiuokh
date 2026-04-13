from __future__ import annotations

import csv
import io
from datetime import datetime
from decimal import Decimal, InvalidOperation
from uuid import uuid4

from flask import Blueprint, g, request
from flask_jwt_extended import create_access_token
from sqlalchemy import func, or_
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from models.address import Address
from models.branch import Branch
from models.category import Category
from models.offer import Offer
from models.order import Order
from models.order_item import OrderItem
from models.product import Product
from models.user import User
from services.catalog_data import icon_key_for_category
from utils.api import error_response, items_response, success_response
from utils.auth import admin_required
from utils.validators import (
    ValidationError,
    get_json_body,
    integer_field,
    optional_string,
    required_string,
)


admin_bp = Blueprint('admin', __name__)

ALLOWED_ORDER_STATUSES = {
    'pending',
    'confirmed',
    'preparing',
    'out_for_delivery',
    'ready_for_pickup',
    'delivered',
    'cancelled',
}


@admin_bp.post('/auth/login')
def admin_login():
    try:
        data = get_json_body()
        email = required_string(data, 'email', label='Email', lower=True)
        password = required_string(data, 'password', label='Password')
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    user = User.query.filter_by(email=email).first()
    if not user or not user.check_password(password):
        return error_response('Invalid email or password.', status=401)
    if not user.is_active:
        return error_response('This account is inactive.', status=403)
    if (user.role or 'customer') != 'admin':
        return error_response('Admin access is required.', status=403)

    token = create_access_token(
        identity=str(user.id),
        additional_claims={'role': user.role},
    )
    return success_response(
        message='Admin login successful.',
        access_token=token,
        user=_serialize_admin_user(user),
    )


@admin_bp.get('/auth/me')
@admin_required
def admin_me():
    return success_response(user=_serialize_admin_user(g.current_user))


@admin_bp.get('/dashboard/summary')
@admin_required
def dashboard_summary():
    product_count = Product.query.count()
    category_count = Category.query.count()
    order_count = Order.query.count()
    customer_count = User.query.filter_by(role='customer').count()
    branch_count = Branch.query.count()
    pending_orders = Order.query.filter(
        Order.order_status.in_(['pending', 'confirmed', 'preparing'])
    ).count()

    delivery_rows = (
        db.session.query(Order.order_status, func.count(Order.id))
        .filter(Order.order_type == 'delivery')
        .group_by(Order.order_status)
        .all()
    )
    recent_orders = Order.query.order_by(Order.created_at.desc()).limit(8).all()

    return success_response(
        summary={
            'total_products': product_count,
            'total_categories': category_count,
            'total_orders': order_count,
            'pending_orders': pending_orders,
            'total_customers': customer_count,
            'total_branches': branch_count,
            'delivery_status_summary': [
                {'status': _normalized_order_status(status), 'count': count}
                for status, count in delivery_rows
            ],
            'recent_orders': [_serialize_order(order) for order in recent_orders],
        }
    )


@admin_bp.get('/products')
@admin_required
def admin_list_products():
    search = (request.args.get('search') or '').strip()
    category_id = request.args.get('category_id', type=int)
    branch_id = request.args.get('branch_id', type=int)
    featured = request.args.get('featured')
    active = request.args.get('active')

    query = Product.query
    if search:
        like_term = f'%{search}%'
        query = query.filter(
            or_(
                Product.name.ilike(like_term),
                Product.name_ar.ilike(like_term),
                Product.sku.ilike(like_term),
                Product.description.ilike(like_term),
            )
        )
    if category_id:
        query = query.filter(Product.category_id == category_id)
    if branch_id:
        query = query.filter(Product.branch_id == branch_id)
    if featured in {'true', 'false'}:
        query = query.filter(Product.is_featured.is_(featured == 'true'))
    if active in {'true', 'false'}:
        query = query.filter(Product.is_active.is_(active == 'true'))

    rows = query.order_by(Product.id.desc()).all()
    return items_response([_serialize_product(row) for row in rows], total=len(rows))


@admin_bp.post('/products')
@admin_required
def admin_create_product():
    try:
        payload = _parse_product_payload()
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    existing_sku = None
    if payload['sku']:
        existing_sku = Product.query.filter_by(sku=payload['sku']).first()
    if existing_sku:
        return error_response('A product already exists for this SKU.', status=409)

    product = Product(**payload)
    db.session.add(product)
    db.session.commit()
    return success_response(
        message='Product created successfully.',
        status=201,
        product=_serialize_product(product),
    )


@admin_bp.get('/products/<int:product_id>')
@admin_required
def admin_get_product(product_id: int):
    product = Product.query.filter_by(id=product_id).first()
    if not product:
        return error_response('Product not found.', status=404)
    return success_response(product=_serialize_product(product))


@admin_bp.patch('/products/<int:product_id>')
@admin_required
def admin_update_product(product_id: int):
    product = Product.query.filter_by(id=product_id).first()
    if not product:
        return error_response('Product not found.', status=404)

    try:
        payload = _parse_product_payload(partial=True)
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    sku = payload.get('sku')
    if sku:
        existing = Product.query.filter(Product.sku == sku, Product.id != product.id).first()
        if existing:
            return error_response('A product already exists for this SKU.', status=409)

    for key, value in payload.items():
        setattr(product, key, value)

    db.session.commit()
    return success_response(message='Product updated successfully.', product=_serialize_product(product))


@admin_bp.delete('/products/<int:product_id>')
@admin_required
def admin_delete_product(product_id: int):
    product = Product.query.filter_by(id=product_id).first()
    if not product:
        return error_response('Product not found.', status=404)
    db.session.delete(product)
    db.session.commit()
    return success_response(message='Product deleted successfully.')


@admin_bp.get('/categories')
@admin_required
def admin_list_categories():
    rows = Category.query.order_by(Category.sort_order.asc(), Category.id.asc()).all()
    return items_response([_serialize_category(row, include_product_count=True) for row in rows], total=len(rows))


@admin_bp.post('/categories')
@admin_required
def admin_create_category():
    try:
        data = get_json_body()
        name = required_string(data, 'name', label='Name')
        name_ar = optional_string(data, 'name_ar')
        image_url = optional_string(data, 'image_url')
        sort_order = integer_field(data, 'sort_order', minimum=0) or 0
        is_active = _bool_field(data.get('is_active'), default=True)
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    if Category.query.filter(func.lower(Category.name) == name.lower()).first():
        return error_response('A category with this name already exists.', status=409)

    category = Category(
        name=name,
        name_ar=name_ar,
        image_url=image_url,
        sort_order=sort_order,
        is_active=is_active,
    )
    db.session.add(category)
    db.session.commit()
    return success_response(
        message='Category created successfully.',
        status=201,
        category=_serialize_category(category, include_product_count=True),
    )


@admin_bp.patch('/categories/<int:category_id>')
@admin_required
def admin_update_category(category_id: int):
    category = Category.query.filter_by(id=category_id).first()
    if not category:
        return error_response('Category not found.', status=404)

    data = get_json_body()
    updates = {}
    if 'name' in data:
        name = required_string(data, 'name', label='Name')
        existing = Category.query.filter(func.lower(Category.name) == name.lower(), Category.id != category_id).first()
        if existing:
            return error_response('A category with this name already exists.', status=409)
        updates['name'] = name
    if 'name_ar' in data:
        updates['name_ar'] = optional_string(data, 'name_ar')
    if 'image_url' in data:
        updates['image_url'] = optional_string(data, 'image_url')
    if 'sort_order' in data:
        sort_order = integer_field(data, 'sort_order', minimum=0, required=True)
        updates['sort_order'] = sort_order
    if 'is_active' in data:
        updates['is_active'] = _bool_field(data.get('is_active'), default=True)

    for key, value in updates.items():
        setattr(category, key, value)

    db.session.commit()
    return success_response(
        message='Category updated successfully.',
        category=_serialize_category(category, include_product_count=True),
    )


@admin_bp.delete('/categories/<int:category_id>')
@admin_required
def admin_delete_category(category_id: int):
    category = Category.query.filter_by(id=category_id).first()
    if not category:
        return error_response('Category not found.', status=404)
    linked_products = Product.query.filter_by(category_id=category_id).count()
    if linked_products:
        return error_response('This category has linked products and cannot be deleted.', status=409)
    db.session.delete(category)
    db.session.commit()
    return success_response(message='Category deleted successfully.')


@admin_bp.get('/branches')
@admin_required
def admin_list_branches():
    rows = Branch.query.order_by(Branch.id.asc()).all()
    return items_response([_serialize_branch(row, include_usage=True) for row in rows], total=len(rows))


@admin_bp.post('/branches')
@admin_required
def admin_create_branch():
    try:
        payload = _parse_branch_payload()
    except ValidationError as exc:
        return error_response(str(exc), status=400)
    branch = Branch(**payload)
    db.session.add(branch)
    db.session.commit()
    return success_response(
        message='Branch created successfully.',
        status=201,
        branch=_serialize_branch(branch, include_usage=True),
    )


@admin_bp.patch('/branches/<int:branch_id>')
@admin_required
def admin_update_branch(branch_id: int):
    branch = Branch.query.filter_by(id=branch_id).first()
    if not branch:
        return error_response('Branch not found.', status=404)

    try:
        payload = _parse_branch_payload(partial=True)
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    for key, value in payload.items():
        setattr(branch, key, value)

    db.session.commit()
    return success_response(message='Branch updated successfully.', branch=_serialize_branch(branch, include_usage=True))


@admin_bp.delete('/branches/<int:branch_id>')
@admin_required
def admin_delete_branch(branch_id: int):
    branch = Branch.query.filter_by(id=branch_id).first()
    if not branch:
        return error_response('Branch not found.', status=404)
    if Product.query.filter_by(branch_id=branch_id).count() or Order.query.filter_by(branch_id=branch_id).count():
        return error_response('This branch is linked to products or orders and cannot be deleted.', status=409)
    db.session.delete(branch)
    db.session.commit()
    return success_response(message='Branch deleted successfully.')


@admin_bp.get('/orders')
@admin_required
def admin_list_orders():
    query = Order.query.outerjoin(User, User.id == Order.user_id)
    search = (request.args.get('search') or '').strip()
    status = (request.args.get('status') or '').strip().lower()
    branch_id = request.args.get('branch_id', type=int)
    date_from = (request.args.get('date_from') or '').strip()
    date_to = (request.args.get('date_to') or '').strip()

    if search:
        like_term = f'%{search}%'
        query = query.filter(
            or_(
                Order.order_number.ilike(like_term),
                User.full_name.ilike(like_term),
                User.email.ilike(like_term),
            )
        )
    if status:
        query = query.filter(Order.order_status == status)
    if branch_id:
        query = query.filter(Order.branch_id == branch_id)
    if date_from:
        parsed = _parse_iso_date(date_from)
        if parsed:
            query = query.filter(Order.created_at >= parsed)
    if date_to:
        parsed = _parse_iso_date(date_to)
        if parsed:
            query = query.filter(Order.created_at <= parsed)

    rows = query.order_by(Order.created_at.desc()).all()
    return items_response([_serialize_order(order, include_customer=True) for order in rows], total=len(rows))


@admin_bp.get('/orders/<int:order_id>')
@admin_required
def admin_get_order(order_id: int):
    order = Order.query.filter_by(id=order_id).first()
    if not order:
        return error_response('Order not found.', status=404)
    return success_response(order=_serialize_order(order, include_customer=True))


@admin_bp.patch('/orders/<int:order_id>')
@admin_required
def admin_update_order(order_id: int):
    order = Order.query.filter_by(id=order_id).first()
    if not order:
        return error_response('Order not found.', status=404)

    data = get_json_body()
    if 'order_status' in data:
        next_status = required_string(data, 'order_status', label='Order status', lower=True)
        if next_status not in ALLOWED_ORDER_STATUSES:
            return error_response('Invalid order status.', status=400)
        order.order_status = next_status
    if 'admin_notes' in data:
        order.admin_notes = optional_string(data, 'admin_notes')
    db.session.commit()
    return success_response(message='Order updated successfully.', order=_serialize_order(order, include_customer=True))


@admin_bp.get('/customers')
@admin_required
def admin_list_customers():
    search = (request.args.get('search') or '').strip()
    query = User.query.filter_by(role='customer')
    if search:
        like_term = f'%{search}%'
        query = query.filter(
            or_(
                User.full_name.ilike(like_term),
                User.email.ilike(like_term),
                User.phone.ilike(like_term),
            )
        )
    rows = query.order_by(User.created_at.desc()).all()
    return items_response([_serialize_customer_summary(user) for user in rows], total=len(rows))


@admin_bp.get('/customers/<int:user_id>')
@admin_required
def admin_get_customer(user_id: int):
    user = User.query.filter_by(id=user_id, role='customer').first()
    if not user:
        return error_response('Customer not found.', status=404)
    return success_response(customer=_serialize_customer_detail(user))


@admin_bp.get('/deliveries')
@admin_required
def admin_list_deliveries():
    status = (request.args.get('status') or '').strip().lower()
    branch_id = request.args.get('branch_id', type=int)
    query = Order.query.filter_by(order_type='delivery')
    if status:
        query = query.filter(Order.order_status == status)
    if branch_id:
        query = query.filter(Order.branch_id == branch_id)
    rows = query.order_by(Order.created_at.desc()).all()
    return items_response([_serialize_order(order, include_customer=True) for order in rows], total=len(rows))


@admin_bp.patch('/deliveries/<int:order_id>')
@admin_required
def admin_update_delivery(order_id: int):
    order = Order.query.filter_by(id=order_id, order_type='delivery').first()
    if not order:
        return error_response('Delivery order not found.', status=404)

    data = get_json_body()
    next_status = required_string(data, 'order_status', label='Order status', lower=True)
    if next_status not in {'preparing', 'out_for_delivery', 'delivered', 'cancelled'}:
        return error_response('Invalid delivery status.', status=400)
    order.order_status = next_status
    if 'admin_notes' in data:
        order.admin_notes = optional_string(data, 'admin_notes')
    db.session.commit()
    return success_response(message='Delivery updated successfully.', order=_serialize_order(order, include_customer=True))


@admin_bp.get('/offers')
@admin_required
def admin_list_offers():
    rows = Offer.query.order_by(Offer.created_at.desc()).all()
    return items_response([_serialize_offer(row) for row in rows], total=len(rows))


@admin_bp.post('/offers')
@admin_required
def admin_create_offer():
    try:
        payload = _parse_offer_payload()
    except ValidationError as exc:
        return error_response(str(exc), status=400)
    offer = Offer(**payload)
    db.session.add(offer)
    db.session.commit()
    return success_response(message='Offer created successfully.', status=201, offer=_serialize_offer(offer))


@admin_bp.patch('/offers/<int:offer_id>')
@admin_required
def admin_update_offer(offer_id: int):
    offer = Offer.query.filter_by(id=offer_id).first()
    if not offer:
        return error_response('Offer not found.', status=404)
    try:
        payload = _parse_offer_payload(partial=True)
    except ValidationError as exc:
        return error_response(str(exc), status=400)
    for key, value in payload.items():
        setattr(offer, key, value)
    db.session.commit()
    return success_response(message='Offer updated successfully.', offer=_serialize_offer(offer))


@admin_bp.delete('/offers/<int:offer_id>')
@admin_required
def admin_delete_offer(offer_id: int):
    offer = Offer.query.filter_by(id=offer_id).first()
    if not offer:
        return error_response('Offer not found.', status=404)
    db.session.delete(offer)
    db.session.commit()
    return success_response(message='Offer deleted successfully.')


@admin_bp.post('/import/products')
@admin_required
def admin_import_products():
    csv_file = request.files.get('file')
    if csv_file is None or not csv_file.filename:
        return error_response('CSV file is required.', status=400)

    raw_bytes = csv_file.read()
    if not raw_bytes:
        return error_response('The uploaded CSV file is empty.', status=400)

    try:
        decoded = raw_bytes.decode('utf-8-sig')
    except UnicodeDecodeError:
        return error_response('CSV must be UTF-8 encoded.', status=400)

    reader = csv.DictReader(io.StringIO(decoded))
    if reader.fieldnames is None:
        return error_response('CSV header row is missing.', status=400)

    imported = 0
    updated = 0
    failed_rows: list[dict] = []

    for row_index, row in enumerate(reader, start=2):
        try:
            payload = _parse_product_import_row(row)
            product = None
            if payload['sku']:
                product = Product.query.filter_by(sku=payload['sku']).first()
            if product is None:
                product = Product.query.filter_by(
                    name=payload['name'],
                    branch_id=payload['branch_id'],
                    category_id=payload['category_id'],
                ).first()

            if product is None:
                product = Product(**payload)
                db.session.add(product)
                imported += 1
            else:
                for key, value in payload.items():
                    setattr(product, key, value)
                updated += 1
        except (ValidationError, ValueError) as exc:
            failed_rows.append({'row': row_index, 'error': str(exc)})

    if failed_rows and imported == 0 and updated == 0:
        db.session.rollback()
        return error_response(
            'No rows were imported.',
            status=400,
            details={'failed_rows': failed_rows},
        )

    db.session.commit()
    return success_response(
        message='Bulk import completed.',
        result={
            'imported': imported,
            'updated': updated,
            'failed_rows': failed_rows,
        },
    )


def _parse_product_payload(*, partial: bool = False) -> dict:
    data = get_json_body()
    payload: dict = {}
    if partial:
        if 'name' in data:
            payload['name'] = required_string(data, 'name', label='Name')
        if 'name_ar' in data:
            payload['name_ar'] = optional_string(data, 'name_ar')
        if 'description' in data:
            payload['description'] = optional_string(data, 'description')
        if 'price' in data:
            payload['price'] = _decimal_field(data.get('price'), label='Price')
        if 'stock_qty' in data:
            payload['stock_qty'] = _coerce_int(data.get('stock_qty'), label='Stock')
        if 'pack_size' in data:
            payload['pack_size'] = optional_string(data, 'pack_size')
        if 'image_url' in data:
            payload['image_url'] = optional_string(data, 'image_url')
        if 'sku' in data:
            payload['sku'] = optional_string(data, 'sku')
        if 'is_featured' in data:
            payload['is_featured'] = _bool_field(data.get('is_featured'), default=False)
        if 'is_active' in data:
            payload['is_active'] = _bool_field(data.get('is_active'), default=True)
        if 'category_id' in data:
            payload['category_id'] = _existing_category_id(data.get('category_id'))
        if 'branch_id' in data:
            payload['branch_id'] = _existing_branch_id(data.get('branch_id'), allow_null=True)
        return payload

    payload['name'] = required_string(data, 'name', label='Name')
    payload['name_ar'] = optional_string(data, 'name_ar')
    payload['description'] = optional_string(data, 'description')
    payload['price'] = _decimal_field(data.get('price'), label='Price')
    payload['stock_qty'] = _coerce_int(data.get('stock_qty', 0), label='Stock')
    payload['pack_size'] = optional_string(data, 'pack_size')
    payload['image_url'] = optional_string(data, 'image_url')
    payload['sku'] = optional_string(data, 'sku')
    payload['is_featured'] = _bool_field(data.get('is_featured'), default=False)
    payload['is_active'] = _bool_field(data.get('is_active'), default=True)
    payload['category_id'] = _existing_category_id(data.get('category_id'))
    payload['branch_id'] = _existing_branch_id(data.get('branch_id'), allow_null=True)
    return payload


def _parse_branch_payload(*, partial: bool = False) -> dict:
    data = get_json_body()
    payload: dict = {}
    fields = {
        'name': ('Name', required_string),
        'city': ('City', optional_string),
        'address': ('Address', optional_string),
        'phone': ('Phone', optional_string),
        'delivery_coverage': ('Delivery coverage', optional_string),
    }
    for key, (label, parser) in fields.items():
        if partial:
            if key not in data:
                continue
        elif key == 'name':
            payload[key] = parser(data, key, label=label)
            continue
        if parser is required_string:
            payload[key] = parser(data, key, label=label)
        else:
            payload[key] = parser(data, key)
    if not partial:
        payload['name'] = required_string(data, 'name', label='Name')
    if 'is_active' in data or not partial:
        payload['is_active'] = _bool_field(data.get('is_active'), default=True)
    if 'pickup_available' in data or not partial:
        payload['pickup_available'] = _bool_field(data.get('pickup_available'), default=True)
    if 'delivery_available' in data or not partial:
        payload['delivery_available'] = _bool_field(data.get('delivery_available'), default=True)
    return payload


def _parse_offer_payload(*, partial: bool = False) -> dict:
    data = get_json_body()
    payload: dict = {}
    if partial:
        if 'title' in data:
            payload['title'] = required_string(data, 'title', label='Title')
        if 'subtitle' in data:
            payload['subtitle'] = optional_string(data, 'subtitle')
        if 'description' in data:
            payload['description'] = optional_string(data, 'description')
        if 'banner_url' in data:
            payload['banner_url'] = optional_string(data, 'banner_url')
        if 'discount_type' in data:
            payload['discount_type'] = optional_string(data, 'discount_type', lower=True)
        if 'discount_value' in data:
            payload['discount_value'] = _decimal_field(data.get('discount_value'), label='Discount value')
        if 'product_id' in data:
            payload['product_id'] = _existing_product_id(data.get('product_id'), allow_null=True)
        if 'category_id' in data:
            payload['category_id'] = _existing_category_id(data.get('category_id'), allow_null=True)
        if 'branch_id' in data:
            payload['branch_id'] = _existing_branch_id(data.get('branch_id'), allow_null=True)
        if 'is_active' in data:
            payload['is_active'] = _bool_field(data.get('is_active'), default=True)
        return payload

    payload['title'] = required_string(data, 'title', label='Title')
    payload['subtitle'] = optional_string(data, 'subtitle')
    payload['description'] = optional_string(data, 'description')
    payload['banner_url'] = optional_string(data, 'banner_url')
    payload['discount_type'] = optional_string(data, 'discount_type', lower=True)
    payload['discount_value'] = _decimal_field(data.get('discount_value', 0), label='Discount value')
    payload['product_id'] = _existing_product_id(data.get('product_id'), allow_null=True)
    payload['category_id'] = _existing_category_id(data.get('category_id'), allow_null=True)
    payload['branch_id'] = _existing_branch_id(data.get('branch_id'), allow_null=True)
    payload['is_active'] = _bool_field(data.get('is_active'), default=True)
    return payload


def _parse_product_import_row(row: dict[str, str]) -> dict:
    def row_value(key: str) -> str:
        return str(row.get(key) or '').strip()

    name = row_value('name')
    if not name:
        raise ValidationError('name is required.')
    category_name = row_value('category')
    if not category_name:
        raise ValidationError('category is required.')
    category = Category.query.filter(func.lower(Category.name) == category_name.lower()).first()
    if not category:
        raise ValidationError(f'Unknown category: {category_name}')

    branch = None
    branch_name = row_value('branch')
    if branch_name:
        branch = Branch.query.filter(func.lower(Branch.name) == branch_name.lower()).first()
        if not branch:
            raise ValidationError(f'Unknown branch: {branch_name}')

    return {
        'name': name,
        'name_ar': row_value('name_ar') or None,
        'description': row_value('description') or None,
        'price': _decimal_field(row_value('price'), label='price'),
        'stock_qty': _coerce_int(row_value('stock') or 0, label='stock'),
        'pack_size': row_value('pack_size') or None,
        'image_url': row_value('image_url') or None,
        'sku': row_value('sku') or None,
        'is_featured': _bool_field(row_value('featured'), default=False),
        'is_active': True,
        'category_id': category.id,
        'branch_id': branch.id if branch else None,
    }


def _existing_category_id(value, *, allow_null: bool = False) -> int | None:
    if value in (None, '') and allow_null:
        return None
    category_id = _coerce_int(value, label='Category')
    if not Category.query.filter_by(id=category_id).first():
        raise ValidationError('Selected category not found.')
    return category_id


def _existing_branch_id(value, *, allow_null: bool = False) -> int | None:
    if value in (None, '') and allow_null:
        return None
    branch_id = _coerce_int(value, label='Branch')
    if not Branch.query.filter_by(id=branch_id).first():
        raise ValidationError('Selected branch not found.')
    return branch_id


def _existing_product_id(value, *, allow_null: bool = False) -> int | None:
    if value in (None, '') and allow_null:
        return None
    product_id = _coerce_int(value, label='Product')
    if not Product.query.filter_by(id=product_id).first():
        raise ValidationError('Selected product not found.')
    return product_id


def _bool_field(value, *, default: bool) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    normalized = str(value).strip().lower()
    if normalized in {'true', '1', 'yes', 'y'}:
        return True
    if normalized in {'false', '0', 'no', 'n'}:
        return False
    raise ValidationError('Boolean field value is invalid.')


def _coerce_int(value, *, label: str) -> int:
    if isinstance(value, bool):
        raise ValidationError(f'{label} must be an integer.')
    try:
        resolved = int(value)
    except (TypeError, ValueError):
        raise ValidationError(f'{label} must be an integer.') from None
    if resolved < 0:
        raise ValidationError(f'{label} must be zero or greater.')
    return resolved


def _decimal_field(value, *, label: str) -> Decimal:
    try:
        resolved = Decimal(str(value).strip())
    except (InvalidOperation, AttributeError):
        raise ValidationError(f'{label} must be a valid number.') from None
    if resolved < 0:
        raise ValidationError(f'{label} must be zero or greater.')
    return resolved


def _parse_iso_date(raw: str) -> datetime | None:
    try:
        return datetime.fromisoformat(raw)
    except ValueError:
        return None


def _serialize_admin_user(user: User):
    return {
        'id': user.id,
        'full_name': user.full_name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'is_active': user.is_active,
    }


def _serialize_branch(branch: Branch, *, include_usage: bool = False):
    payload = {
        'id': branch.id,
        'name': branch.name,
        'city': branch.city,
        'address': branch.address,
        'phone': branch.phone,
        'is_active': branch.is_active,
        'pickup_available': branch.pickup_available,
        'delivery_available': branch.delivery_available,
        'delivery_coverage': branch.delivery_coverage,
    }
    if include_usage:
        payload['product_count'] = Product.query.filter_by(branch_id=branch.id).count()
        payload['order_count'] = Order.query.filter_by(branch_id=branch.id).count()
    return payload


def _serialize_category(category: Category, *, include_product_count: bool = False):
    payload = {
        'id': category.id,
        'name': category.name,
        'name_ar': category.name_ar,
        'image_url': category.image_url,
        'icon_key': icon_key_for_category(category.name),
        'sort_order': category.sort_order,
        'is_active': category.is_active,
    }
    if include_product_count:
        payload['product_count'] = Product.query.filter_by(category_id=category.id).count()
    return payload


def _serialize_product(product: Product):
    category = Category.query.filter_by(id=product.category_id).first()
    branch = Branch.query.filter_by(id=product.branch_id).first() if product.branch_id else None
    return {
        'id': product.id,
        'name': product.name,
        'name_ar': product.name_ar,
        'sku': product.sku,
        'description': product.description,
        'price': float(product.price or 0),
        'stock_qty': product.stock_qty,
        'pack_size': product.pack_size,
        'image_url': product.resolved_image_url,
        'category_id': product.category_id,
        'branch_id': product.branch_id,
        'is_featured': product.is_featured,
        'is_active': product.is_active,
        'category_name': category.name if category else None,
        'branch_name': branch.name if branch else None,
    }


def _serialize_order(order: Order, *, include_customer: bool = False):
    branch = Branch.query.filter_by(id=order.branch_id).first() if order.branch_id else None
    address = Address.query.filter_by(id=order.address_id).first() if order.address_id else None
    user = User.query.filter_by(id=order.user_id).first() if order.user_id else None
    items = OrderItem.query.filter_by(order_id=order.id).order_by(OrderItem.id.asc()).all()
    payload = {
        'id': order.id,
        'order_number': order.order_number,
        'order_type': order.order_type,
        'order_status': _normalized_order_status(order.order_status),
        'payment_method': order.payment_method,
        'payment_status': order.payment_status,
        'subtotal': float(order.subtotal or 0),
        'delivery_fee': float(order.delivery_fee or 0),
        'discount_amount': float(order.discount_amount or 0),
        'total_amount': float(order.total_amount or 0),
        'notes': order.notes,
        'admin_notes': order.admin_notes,
        'created_at': order.created_at.isoformat() if order.created_at else None,
        'branch': _serialize_branch(branch) if branch else None,
        'address': None if not address else {
            'id': address.id,
            'label': address.label,
            'city': address.city,
            'neighborhood': address.neighborhood,
            'address_line': address.address_line,
        },
        'items': [
            {
                'id': item.id,
                'product_id': item.product_id,
                'product_name': item.product_name,
                'price': float(item.price or 0),
                'quantity': item.quantity,
                'line_total': float(item.line_total or 0),
            }
            for item in items
        ],
    }
    if include_customer:
        payload['customer'] = {
            'id': user.id if user else 0,
            'full_name': user.full_name if user else 'Guest customer',
            'email': user.email if user else None,
            'phone': user.phone if user else None,
            'guest_session_id': None if user else order.guest_session_id,
        }
    return payload


def _serialize_customer_summary(user: User):
    orders = Order.query.filter_by(user_id=user.id).all()
    total_spent = sum(float(order.total_amount or 0) for order in orders)
    return {
        'id': user.id,
        'full_name': user.full_name,
        'email': user.email,
        'phone': user.phone,
        'is_active': user.is_active,
        'created_at': user.created_at.isoformat() if user.created_at else None,
        'order_count': len(orders),
        'total_spent': total_spent,
    }


def _serialize_customer_detail(user: User):
    orders = Order.query.filter_by(user_id=user.id).order_by(Order.created_at.desc()).all()
    addresses = Address.query.filter_by(user_id=user.id).order_by(Address.created_at.desc()).all()
    latest_order = orders[0] if orders else None
    preferred_branch = None
    if latest_order and latest_order.branch_id:
        branch = Branch.query.filter_by(id=latest_order.branch_id).first()
        if branch:
            preferred_branch = _serialize_branch(branch)

    return {
        **_serialize_customer_summary(user),
        'addresses': [
            {
                'id': address.id,
                'label': address.label,
                'city': address.city,
                'neighborhood': address.neighborhood,
                'address_line': address.address_line,
                'is_default': address.is_default,
            }
            for address in addresses
        ],
        'preferred_branch': preferred_branch,
        'orders': [_serialize_order(order) for order in orders],
    }


def _serialize_offer(offer: Offer):
    return {
        'id': offer.id,
        'title': offer.title,
        'subtitle': offer.subtitle,
        'description': offer.description,
        'banner_url': offer.banner_url,
        'discount_type': offer.discount_type,
        'discount_value': float(offer.discount_value or 0),
        'product_id': offer.product_id,
        'category_id': offer.category_id,
        'branch_id': offer.branch_id,
        'starts_at': offer.starts_at.isoformat() if offer.starts_at else None,
        'ends_at': offer.ends_at.isoformat() if offer.ends_at else None,
        'is_active': offer.is_active,
        'created_at': offer.created_at.isoformat() if offer.created_at else None,
    }


def _normalized_order_status(status: str | None):
    if status == 'placed':
        return 'pending'
    return status or 'pending'
