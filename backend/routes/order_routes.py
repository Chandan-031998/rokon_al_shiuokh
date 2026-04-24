from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from flask import Blueprint
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from models.address import Address
from models.branch import Branch
from models.cart_item import CartItem
from models.order import Order
from models.order_item import OrderItem
from models.product import Product
from models.support_setting import SupportSetting
from utils.api import error_response, items_response, success_response
from utils.auth import resolve_cart_owner
from utils.validators import (
    ValidationError,
    get_json_body,
    integer_field,
    optional_string,
)


order_bp = Blueprint('orders', __name__)


@order_bp.get('/')
def list_orders():
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        query = Order.query.order_by(Order.created_at.desc())
        if owner.user_id is not None:
            orders = query.filter_by(user_id=owner.user_id).all()
        else:
            orders = query.filter_by(guest_session_id=owner.guest_session_id).all()
    except SQLAlchemyError:
        db.session.rollback()
        return items_response([])

    return items_response([_serialize_order(order) for order in orders])


@order_bp.get('/<int:order_id>')
def get_order_details(order_id: int):
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        query = Order.query.filter_by(id=order_id)
        if owner.user_id is not None:
            order = query.filter_by(user_id=owner.user_id).first()
        else:
            order = query.filter_by(guest_session_id=owner.guest_session_id).first()
    except SQLAlchemyError:
        db.session.rollback()
        return error_response('Unable to load order right now.', status=500)

    if not order:
        return error_response('Order not found.', status=404)

    return success_response(order=_serialize_order(order))


@order_bp.post('/')
def create_order():
    try:
        owner = resolve_cart_owner()
    except ValueError:
        return error_response('Guest session id is required.', status=400)

    try:
        data = get_json_body()
        order_type = optional_string(data, 'order_type', lower=True) or 'delivery'
        branch_id = integer_field(data, 'branch_id', required=True, minimum=1, label='branch_id')
        address_id = integer_field(data, 'address_id', minimum=1, label='address_id')
        payment_method = optional_string(data, 'payment_method', lower=True) or 'cod'
        notes = optional_string(data, 'notes')
        address_payload = data.get('address') or {}
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    if order_type not in {'delivery', 'pickup'}:
        return error_response('order_type must be delivery or pickup.', status=400)
    if order_type == 'delivery' and address_id is None and not isinstance(address_payload, dict):
        return error_response('address is required for delivery orders.', status=400)

    try:
        branch = Branch.query.filter_by(id=branch_id, is_active=True).first()
        if not branch:
            return error_response('Selected branch not found.', status=404)
        if order_type == 'delivery' and not branch.delivery_available:
            return error_response('Delivery is not available for the selected branch.', status=400)
        if order_type == 'pickup' and not branch.pickup_available:
            return error_response('Pickup is not available for the selected branch.', status=400)

        cart_items = _owner_cart_items(owner)
        if not cart_items:
            return error_response('Cart is empty.', status=400)

        payment_settings = SupportSetting.query.order_by(SupportSetting.id.asc()).first()
        if not _is_payment_method_enabled(payment_settings, payment_method):
            return error_response('Selected payment method is unavailable.', status=400)

        address = None
        if order_type == 'delivery':
            address = _resolve_delivery_address(owner, address_id, address_payload)
            if isinstance(address, tuple):
                return address

        subtotal = Decimal('0')
        order_items = []

        for cart_item in cart_items:
            product = Product.query.filter_by(id=cart_item.product_id, is_active=True).first()
            if not product:
                return error_response('One or more cart products are unavailable.', status=400)
            if not product.is_available_for_branch(branch.id):
                return error_response(
                    f'{product.name} is not available for the selected branch.',
                    status=400,
                )
            if cart_item.branch_id is not None and cart_item.branch_id != branch.id:
                return error_response(
                    f'{product.name} is assigned to a different branch in the cart.',
                    status=400,
                )

            unit_price = _effective_product_price(
                product,
                region_code=branch.region_code if branch else None,
            )
            line_total = unit_price * cart_item.quantity
            subtotal += line_total
            order_items.append(OrderItem(
                product_id=product.id,
                product_name=product.name,
                price=unit_price,
                quantity=cart_item.quantity,
                line_total=line_total,
            ))

        delivery_fee = Decimal('12.00') if order_type == 'delivery' else Decimal('0')
        total_amount = subtotal + delivery_fee

        order = Order(
            user_id=owner.user_id,
            guest_session_id=owner.guest_session_id,
            branch_id=branch.id,
            address_id=address.id if address else None,
            order_number=_generate_order_number(),
            order_type=order_type,
            payment_method=payment_method,
            payment_status='pending',
            order_status='pending',
            subtotal=subtotal,
            delivery_fee=delivery_fee,
            discount_amount=Decimal('0'),
            total_amount=total_amount,
            notes=notes,
        )
        db.session.add(order)
        db.session.flush()

        for item in order_items:
            item.order_id = order.id
            db.session.add(item)

        for cart_item in cart_items:
            db.session.delete(cart_item)

        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        return error_response('Unable to place order right now.', status=500)

    return success_response(
        message='Order placed successfully.',
        status=201,
        order=_serialize_order(order, branch=branch, address=address, items=order_items),
    )


def _owner_cart_items(owner):
    query = CartItem.query.order_by(CartItem.created_at.asc())
    if owner.user_id is not None:
        return query.filter_by(user_id=owner.user_id).all()
    return query.filter_by(guest_session_id=owner.guest_session_id).all()


def _create_address(owner, payload):
    label = (payload.get('label') or 'Delivery').strip()
    city = (payload.get('city') or '').strip()
    neighborhood = (payload.get('neighborhood') or '').strip()
    address_line = (payload.get('address_line') or '').strip()

    if not city or not neighborhood or not address_line:
        return error_response(
            'city, neighborhood, and address_line are required for delivery.',
            status=400,
        )

    address = Address(
        user_id=owner.user_id,
        guest_session_id=owner.guest_session_id,
        label=label,
        city=city,
        neighborhood=neighborhood,
        address_line=address_line,
        is_default=False,
    )
    db.session.add(address)
    db.session.flush()
    return address


def _resolve_delivery_address(owner, address_id: int | None, payload):
    if address_id is not None:
        query = Address.query.filter_by(id=address_id)
        if owner.user_id is not None:
            address = query.filter_by(user_id=owner.user_id).first()
        else:
            address = query.filter_by(guest_session_id=owner.guest_session_id).first()
        if address is None:
            return error_response('Selected address not found.', status=404)
        return address
    return _create_address(owner, payload)


def _generate_order_number():
    timestamp = datetime.utcnow().strftime('%Y%m%d%H%M%S')
    return f'RAS-{timestamp}'


def _serialize_order(order, branch=None, address=None, items=None):
    resolved_branch = branch or Branch.query.filter_by(id=order.branch_id).first()
    resolved_address = address
    if resolved_address is None and order.address_id is not None:
        resolved_address = Address.query.filter_by(id=order.address_id).first()
    resolved_items = items
    if resolved_items is None:
        resolved_items = OrderItem.query.filter_by(order_id=order.id).all()

    return {
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
        'branch': None if not resolved_branch else {
            'id': resolved_branch.id,
            'name': resolved_branch.name,
            'city': resolved_branch.city,
            'address': resolved_branch.address,
            'phone': resolved_branch.phone,
        },
        'address': None if not resolved_address else {
            'id': resolved_address.id,
            'label': resolved_address.label,
            'city': resolved_address.city,
            'neighborhood': resolved_address.neighborhood,
            'address_line': resolved_address.address_line,
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
            for item in resolved_items
        ],
    }


def _normalized_order_status(status: str | None):
    if status == 'placed':
        return 'pending'
    return status or 'pending'


def _effective_product_price(
    product: Product,
    *,
    region_code: str | None = None,
) -> Decimal:
    resolved_sale_price = product.effective_sale_price(region_code)
    resolved_price = product.effective_price(region_code)
    if resolved_sale_price is not None:
        sale_price = Decimal(str(resolved_sale_price))
        base_price = Decimal(str(resolved_price or 0))
        if sale_price > 0 and sale_price < base_price:
            return sale_price
    return Decimal(str(resolved_price or 0))


def _is_payment_method_enabled(settings: SupportSetting | None, payment_method: str) -> bool:
    if payment_method == 'cod':
        return settings is None or bool(settings.payment_cod_enabled)
    if payment_method == 'card':
        return settings is not None and bool(settings.payment_card_enabled)
    if payment_method == 'bank_transfer':
        return settings is not None and bool(settings.payment_bank_transfer_enabled)
    return False
