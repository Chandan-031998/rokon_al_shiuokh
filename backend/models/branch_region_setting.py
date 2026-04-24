from datetime import datetime

from extensions import db


class BranchRegionSetting(db.Model):
    __tablename__ = 'branch_region_settings'

    id = db.Column(db.BigInteger, primary_key=True)
    branch_id = db.Column(
        db.BigInteger,
        db.ForeignKey('branches.id', ondelete='CASCADE'),
        nullable=False,
        index=True,
    )
    region_code = db.Column(db.String(2), nullable=False, index=True)
    currency_code = db.Column(db.String(3), nullable=False)
    is_visible = db.Column(db.Boolean, default=True)
    pickup_available = db.Column(db.Boolean, default=True)
    delivery_available = db.Column(db.Boolean, default=True)
    delivery_coverage = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
