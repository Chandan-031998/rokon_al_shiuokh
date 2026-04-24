from datetime import datetime

from extensions import db


class ProductImage(db.Model):
    __tablename__ = 'product_images'

    id = db.Column(db.BigInteger, primary_key=True)
    product_id = db.Column(
        db.BigInteger,
        db.ForeignKey('products.id', ondelete='CASCADE'),
        nullable=False,
    )
    image_url = db.Column(db.Text, nullable=False)
    sort_order = db.Column(db.Integer, nullable=False, default=0)
    is_primary = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
