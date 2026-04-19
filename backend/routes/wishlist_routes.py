from __future__ import annotations

from flask import Blueprint
from sqlalchemy.exc import IntegrityError

from extensions import db
from models.product import Product
from models.wishlist_item import WishlistItem
from utils.api import error_response, items_response, success_response
from utils.auth import resolve_authenticated_user


wishlist_bp = Blueprint('wishlist', __name__)


@wishlist_bp.get('/')
def list_wishlist_items():
    user = resolve_authenticated_user(required=True)
    if user is None:
        return error_response('Authentication is required.', status=401)

    rows = (
        WishlistItem.query.filter_by(user_id=user.id)
        .order_by(WishlistItem.created_at.desc())
        .all()
    )
    items = []
    for row in rows:
        product = Product.query.filter_by(id=row.product_id, is_active=True).first()
        if product is None:
            continue
        items.append(_serialize_wishlist_item(row, product))
    return items_response(items, total=len(items))


@wishlist_bp.post('/<int:product_id>')
def add_wishlist_item(product_id: int):
    user = resolve_authenticated_user(required=True)
    if user is None:
        return error_response('Authentication is required.', status=401)

    product = Product.query.filter_by(id=product_id, is_active=True).first()
    if not product:
        return error_response('Product not found.', status=404)

    existing = WishlistItem.query.filter_by(user_id=user.id, product_id=product_id).first()
    if existing:
        return success_response(message='Product is already in wishlist.')

    row = WishlistItem(user_id=user.id, product_id=product_id)
    try:
        db.session.add(row)
        db.session.commit()
    except IntegrityError:
        db.session.rollback()
        return success_response(message='Product is already in wishlist.')
    return success_response(
        message='Product added to wishlist.',
        status=201,
        item=_serialize_wishlist_item(row, product),
    )


@wishlist_bp.delete('/<int:product_id>')
def remove_wishlist_item(product_id: int):
    user = resolve_authenticated_user(required=True)
    if user is None:
        return error_response('Authentication is required.', status=401)

    row = WishlistItem.query.filter_by(user_id=user.id, product_id=product_id).first()
    if row is None:
        return success_response(message='Product was not in wishlist.')
    db.session.delete(row)
    db.session.commit()
    return success_response(message='Product removed from wishlist.')


def _serialize_wishlist_item(row: WishlistItem, product: Product):
    return {
        'id': row.id,
        'product_id': row.product_id,
        'created_at': row.created_at.isoformat() if row.created_at else None,
        'product': {
            'id': product.id,
            'name': product.name,
            'name_ar': product.name_ar,
            'image_url': product.resolved_image_url,
            'price': float(product.price or 0),
            'sale_price': float(product.sale_price) if product.sale_price is not None else None,
            'category_id': product.category_id,
            'branch_id': product.branch_id,
            'is_active': product.is_active,
        },
    }
