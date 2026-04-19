from datetime import datetime

from extensions import db


class FilterGroup(db.Model):
    __tablename__ = 'filter_groups'

    id = db.Column(db.BigInteger, primary_key=True)
    name = db.Column(db.String(140), nullable=False)
    slug = db.Column(db.String(160), nullable=False, unique=True)
    filter_type = db.Column(db.String(40), nullable=False, default='multi_select')
    sort_order = db.Column(db.Integer, nullable=False, default=0)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    is_public = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
