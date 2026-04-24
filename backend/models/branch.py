from datetime import datetime
from extensions import db


class Branch(db.Model):
    __tablename__ = 'branches'

    id = db.Column(db.BigInteger, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    region_code = db.Column(db.String(2))
    default_currency_code = db.Column(db.String(3))
    city = db.Column(db.String(120))
    address = db.Column(db.Text)
    latitude = db.Column(db.Numeric(10, 7))
    longitude = db.Column(db.Numeric(10, 7))
    phone = db.Column(db.String(30))
    map_link = db.Column(db.Text)
    is_active = db.Column(db.Boolean, default=True)
    pickup_available = db.Column(db.Boolean, default=True)
    delivery_available = db.Column(db.Boolean, default=True)
    delivery_coverage = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    region_settings = db.relationship(
        'BranchRegionSetting',
        backref='branch',
        lazy='selectin',
        cascade='all, delete-orphan',
        order_by='BranchRegionSetting.region_code.asc(), BranchRegionSetting.id.asc()',
    )
