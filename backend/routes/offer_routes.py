from datetime import datetime

from flask import Blueprint

from models.offer import Offer
from utils.api import api_response


offer_bp = Blueprint('offers', __name__)


@offer_bp.get('/active')
def active_offers():
    now = datetime.utcnow()
    rows = (
        Offer.query.filter_by(is_active=True)
        .filter((Offer.starts_at.is_(None)) | (Offer.starts_at <= now))
        .filter((Offer.ends_at.is_(None)) | (Offer.ends_at >= now))
        .order_by(Offer.created_at.desc())
        .all()
    )
    return api_response([
        {
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
        }
        for offer in rows
    ])
