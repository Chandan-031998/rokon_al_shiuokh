from datetime import datetime

from extensions import db


class Offer(db.Model):
    __tablename__ = 'offers'

    id = db.Column(db.BigInteger, primary_key=True)
    title = db.Column(db.String(150), nullable=False)
    subtitle = db.Column(db.String(180))
    description = db.Column(db.Text)
    banner_url = db.Column(db.Text)
    discount_type = db.Column(db.String(20))
    discount_value = db.Column(db.Numeric(10, 2), default=0)
    product_id = db.Column(db.BigInteger, db.ForeignKey('products.id'))
    category_id = db.Column(db.BigInteger, db.ForeignKey('categories.id'))
    branch_id = db.Column(db.BigInteger, db.ForeignKey('branches.id'))
    starts_at = db.Column(db.DateTime)
    ends_at = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
