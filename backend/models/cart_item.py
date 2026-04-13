from datetime import datetime
from extensions import db


class CartItem(db.Model):
    __tablename__ = 'cart_items'

    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('users.id'))
    guest_session_id = db.Column(db.String(120), index=True)
    product_id = db.Column(db.BigInteger, db.ForeignKey('products.id'), nullable=False)
    branch_id = db.Column(db.BigInteger, db.ForeignKey('branches.id'))
    quantity = db.Column(db.Integer, nullable=False, default=1)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
