from datetime import datetime
from extensions import db


class Order(db.Model):
    __tablename__ = 'orders'

    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('users.id'))
    guest_session_id = db.Column(db.String(120), index=True)
    branch_id = db.Column(db.BigInteger, db.ForeignKey('branches.id'))
    address_id = db.Column(db.BigInteger, db.ForeignKey('addresses.id'))
    order_number = db.Column(db.String(40), unique=True, nullable=False)
    order_type = db.Column(db.String(20), default='delivery')
    payment_method = db.Column(db.String(30), default='cod')
    payment_status = db.Column(db.String(30), default='pending')
    order_status = db.Column(db.String(30), default='placed')
    subtotal = db.Column(db.Numeric(10, 2), default=0)
    delivery_fee = db.Column(db.Numeric(10, 2), default=0)
    discount_amount = db.Column(db.Numeric(10, 2), default=0)
    total_amount = db.Column(db.Numeric(10, 2), default=0)
    delivery_slot = db.Column(db.String(80))
    notes = db.Column(db.Text)
    admin_notes = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
