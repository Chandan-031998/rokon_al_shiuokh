from datetime import datetime
from extensions import db


class Address(db.Model):
    __tablename__ = 'addresses'

    id = db.Column(db.BigInteger, primary_key=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('users.id'))
    guest_session_id = db.Column(db.String(120), index=True)
    label = db.Column(db.String(60), default='Home')
    city = db.Column(db.String(100))
    neighborhood = db.Column(db.String(100))
    address_line = db.Column(db.Text, nullable=False)
    latitude = db.Column(db.Numeric(10, 7))
    longitude = db.Column(db.Numeric(10, 7))
    is_default = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
