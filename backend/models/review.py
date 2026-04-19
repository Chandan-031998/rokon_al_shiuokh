from datetime import datetime

from extensions import db


class Review(db.Model):
    __tablename__ = 'reviews'

    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('users.id'), nullable=False)
    product_id = db.Column(db.BigInteger, db.ForeignKey('products.id'), nullable=False)
    order_id = db.Column(db.BigInteger, db.ForeignKey('orders.id'))
    rating = db.Column(db.Integer, nullable=False)
    title = db.Column(db.String(180))
    body = db.Column(db.Text)
    moderation_status = db.Column(db.String(30), nullable=False, default='pending')
    moderation_notes = db.Column(db.Text)
    is_verified_purchase = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
