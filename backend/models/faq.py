from datetime import datetime

from extensions import db


class Faq(db.Model):
    __tablename__ = 'faqs'

    id = db.Column(db.BigInteger, primary_key=True)
    question = db.Column(db.String(240), nullable=False)
    answer = db.Column(db.Text, nullable=False)
    sort_order = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
