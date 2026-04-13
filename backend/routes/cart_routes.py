from __future__ import annotations

from decimal import Decimal

from flask import Blueprint
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from models.branch import Branch
from models.cart_item import CartItem
from models.product import Product
from services.db_compat import column_exists, load_only_existing
from utils.api import api_response, error_response
from utils.auth import resolve_cart_owner
from utils.validators import ValidationError, get_json_body, integer_field


cart_bp = Blueprint('cart', __name__)


@cart_bp.get('/')
def get_cart():
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return _empty_cart_response()

    return _cart_response(owner)


@cart_bp.post('/items')
def add_cart_item():
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        data = get_json_body()
        product_id = integer_field(data, 'product_id', required=True, minimum=1, label='product_id')
        branch_id = integer_field(data, 'branch_id', minimum=1, label='branch_id')
        quantity = integer_field(data, 'quantity', minimum=1, label='quantity') or 1
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    try:
        product_query = Product.query
        option = load_only_existing(
            Product,
            'products',
            ['id', 'branch_id', 'is_active'],
        )
        if option is not None:
            product_query = product_query.options(option)
        product = product_query.filter_by(id=product_id, is_active=True).first()
        if not product:
            return error_response('Product not found.', status=404)

        resolved_branch_id = branch_id or product.branch_id
        cart_item = _find_cart_item(owner, product_id, resolved_branch_id)
        if cart_item:
            cart_item.quantity += quantity
        else:
            cart_item = CartItem(
                user_id=owner.user_id,
                guest_session_id=owner.guest_session_id,
                product_id=product_id,
                branch_id=resolved_branch_id,
                quantity=quantity,
            )
            db.session.add(cart_item)

        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        return error_response('Unable to add cart item.', status=500)

    return _cart_response(owner)


@cart_bp.patch('/items/<int:item_id>')
def update_cart_item(item_id: int):
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        data = get_json_body()
        quantity = integer_field(data, 'quantity', minimum=0, label='quantity')
        branch_id = integer_field(data, 'branch_id', minimum=1, label='branch_id')
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    try:
        cart_item = _find_owned_item(owner, item_id)
        if not cart_item:
            return error_response('Cart item not found.', status=404)

        if quantity == 0:
            db.session.delete(cart_item)
        else:
            if quantity is not None:
                cart_item.quantity = quantity
            if branch_id is not None:
                cart_item.branch_id = branch_id

        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        return error_response('Unable to update cart item.', status=500)

    return _cart_response(owner)


@cart_bp.delete('/items/<int:item_id>')
def remove_cart_item(item_id: int):
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        cart_item = _find_owned_item(owner, item_id)
        if not cart_item:
            return error_response('Cart item not found.', status=404)

        db.session.delete(cart_item)
        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        return error_response('Unable to remove cart item.', status=500)

    return _cart_response(owner)


def _find_cart_item(owner, product_id: int, branch_id: int | None):
    query = _owner_query(owner).filter_by(product_id=product_id)
    if branch_id is None:
        return query.filter(CartItem.branch_id.is_(None)).first()
    return query.filter_by(branch_id=branch_id).first()


def _find_owned_item(owner, item_id: int):
    return _owner_query(owner).filter_by(id=item_id).first()


def _owner_query(owner):
    query = CartItem.query
    if owner.user_id is not None:
        return query.filter_by(user_id=owner.user_id)
    return query.filter_by(guest_session_id=owner.guest_session_id)


def _cart_response(owner):
    try:
        items = _owner_query(owner).order_by(CartItem.created_at.desc()).all()
        if not items:
            return _empty_cart_response()

        product_ids = [item.product_id for item in items]
        branch_ids = [item.branch_id for item in items if item.branch_id is not None]

        product_query = Product.query
        product_option = load_only_existing(
            Product,
            'products',
            [
                'id',
                'name',
                'name_ar',
                'price',
                'image_url',
                'description',
                'sku',
                'category_id',
                'branch_id',
                'pack_size',
            ],
        )
        if product_option is not None:
            product_query = product_query.options(product_option)
        products = {
            product.id: product
            for product in product_query.filter(Product.id.in_(product_ids)).all()
        } if product_ids else {}

        branch_query = Branch.query
        branch_option = load_only_existing(
            Branch,
            'branches',
            ['id', 'name', 'city', 'address', 'phone'],
        )
        if branch_option is not None:
            branch_query = branch_query.options(branch_option)
        branches = {
            branch.id: branch
            for branch in branch_query.filter(Branch.id.in_(branch_ids)).all()
        } if branch_ids else {}
    except SQLAlchemyError:
        return error_response('Unable to load cart.', status=500)

    subtotal = Decimal('0')
    serialized_items = []
    has_pack_size = column_exists('products', 'pack_size')

    for item in items:
        product = products.get(item.product_id)
        if not product:
            continue

        price_value = Decimal(str(product.price or 0))
        line_total = price_value * item.quantity
        subtotal += line_total
        branch = branches.get(item.branch_id)

        serialized_items.append({
            'id': item.id,
            'quantity': item.quantity,
            'branch_id': item.branch_id,
            'line_total': float(line_total),
            'product': {
                'id': product.id,
                'name': product.name,
                'name_ar': product.name_ar,
                'price': float(price_value),
                'image_url': product.resolved_image_url,
                'description': product.description,
                'sku': product.sku,
                'category_id': product.category_id,
                'branch_id': product.branch_id,
                'pack_size': product.pack_size if has_pack_size else None,
            },
            'branch': None if not branch else {
                'id': branch.id,
                'name': branch.name,
                'city': branch.city,
                'address': branch.address,
                'phone': branch.phone,
            },
        })

    return api_response({
        'items': serialized_items,
        'subtotal': float(subtotal),
        'total': float(subtotal),
        'currency': 'SAR',
    })


def _empty_cart_response():
    return api_response({
        'items': [],
        'subtotal': 0.0,
        'total': 0.0,
        'currency': 'SAR',
    })
