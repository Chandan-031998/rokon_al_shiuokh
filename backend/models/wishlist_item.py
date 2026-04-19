from datetime import datetime

from extensions import db


class WishlistItem(db.Model):
    __tablename__ = 'wishlist_items'

    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('users.id'), nullable=False)
    product_id = db.Column(db.BigInteger, db.ForeignKey('products.id'), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
