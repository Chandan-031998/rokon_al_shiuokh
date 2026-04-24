from datetime import datetime

from extensions import db


class ProductRegionPrice(db.Model):
    __tablename__ = 'product_region_prices'

    id = db.Column(db.BigInteger, primary_key=True)
    product_id = db.Column(
        db.BigInteger,
        db.ForeignKey('products.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    region_code = db.Column(db.String(2), nullable=False, index=True)
    currency_code = db.Column(db.String(3), nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    sale_price = db.Column(db.Numeric(10, 2))
    is_visible = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
