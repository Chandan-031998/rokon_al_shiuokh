from __future__ import annotations

from flask import Blueprint

from extensions import db
from models.order import Order
from models.order_item import OrderItem
from models.product import Product
from models.review import Review
from utils.api import error_response, items_response, success_response
from utils.auth import resolve_authenticated_user
from utils.validators import ValidationError, get_json_body, optional_string


review_bp = Blueprint('reviews', __name__)

ALLOWED_REVIEW_STATUSES = {'pending', 'approved', 'rejected'}


@review_bp.get('/product/<int:product_id>')
def list_product_reviews(product_id: int):
    product = Product.query.filter_by(id=product_id, is_active=True).first()
    if not product:
        return error_response('Product not found.', status=404)

    rows = (
        Review.query.filter_by(product_id=product_id, moderation_status='approved')
        .order_by(Review.created_at.desc())
        .all()
    )
    return items_response([_serialize_review(row, include_private=False) for row in rows], total=len(rows))


@review_bp.post('/')
def submit_review():
    user = resolve_authenticated_user(required=True)
    if user is None:
        return error_response('Authentication is required.', status=401)

    try:
        payload = _parse_review_payload()
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    product = Product.query.filter_by(id=payload['product_id']).first()
    if not product:
        return error_response('Product not found.', status=404)

    existing = Review.query.filter_by(
        user_id=user.id,
        product_id=payload['product_id'],
        order_id=payload.get('order_id'),
    ).first()
    if existing:
        return error_response('A review already exists for this purchase.', status=409)

    verified_purchase = _is_verified_purchase(user.id, payload['product_id'], payload.get('order_id'))

    row = Review(
        user_id=user.id,
        product_id=payload['product_id'],
        order_id=payload.get('order_id'),
        rating=payload['rating'],
        title=payload.get('title'),
        body=payload.get('body'),
        moderation_status='pending',
        is_verified_purchase=verified_purchase,
    )
    db.session.add(row)
    db.session.commit()
    return success_response(
        message='Review submitted successfully and is pending moderation.',
        status=201,
        review=_serialize_review(row, include_private=True),
    )


def _parse_review_payload() -> dict:
    data = get_json_body()
    product_id = data.get('product_id')
    order_id = data.get('order_id')
    rating = data.get('rating')
    try:
        product_id = int(product_id)
    except (TypeError, ValueError):
        raise ValidationError('Product is required.') from None
    if order_id not in (None, ''):
        try:
            order_id = int(order_id)
        except (TypeError, ValueError):
            raise ValidationError('Order must be an integer.') from None
    try:
        rating = int(rating)
    except (TypeError, ValueError):
        raise ValidationError('Rating must be an integer.') from None
    if rating < 1 or rating > 5:
        raise ValidationError('Rating must be between 1 and 5.')
    return {
        'product_id': product_id,
        'order_id': order_id,
        'rating': rating,
        'title': optional_string(data, 'title'),
        'body': optional_string(data, 'body'),
    }


def _is_verified_purchase(user_id: int, product_id: int, order_id: int | None) -> bool:
    query = (
        db.session.query(OrderItem.id)
        .join(Order, Order.id == OrderItem.order_id)
        .filter(
            Order.user_id == user_id,
            OrderItem.product_id == product_id,
        )
    )
    if order_id is not None:
        query = query.filter(Order.id == order_id)
    return query.first() is not None


def _serialize_review(review: Review, *, include_private: bool):
    payload = {
        'id': review.id,
        'user_id': review.user_id,
        'product_id': review.product_id,
        'order_id': review.order_id,
        'rating': review.rating,
        'title': review.title,
        'body': review.body,
        'moderation_status': review.moderation_status,
        'is_verified_purchase': review.is_verified_purchase,
        'created_at': review.created_at.isoformat() if review.created_at else None,
    }
    if include_private:
        payload['moderation_notes'] = review.moderation_notes
    return payload
