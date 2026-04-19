from datetime import datetime

from extensions import db


class FilterValue(db.Model):
    __tablename__ = 'filter_values'

    id = db.Column(db.BigInteger, primary_key=True)
    group_id = db.Column(
        db.BigInteger,
        db.ForeignKey('filter_groups.id', ondelete='cascade'),
        nullable=False,
    )
    value = db.Column(db.String(140), nullable=False)
    value_ar = db.Column(db.String(140))
    slug = db.Column(db.String(160), nullable=False)
    sort_order = db.Column(db.Integer, nullable=False, default=0)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
