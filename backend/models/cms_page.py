from datetime import datetime

from extensions import db


class CmsPage(db.Model):
    __tablename__ = 'cms_pages'

    id = db.Column(db.BigInteger, primary_key=True)
    slug = db.Column(db.String(160), nullable=False, unique=True)
    title = db.Column(db.String(180), nullable=False)
    section = db.Column(db.String(60), nullable=False, index=True)
    excerpt = db.Column(db.String(280))
    body = db.Column(db.Text)
    image_url = db.Column(db.Text)
    cta_label = db.Column(db.String(80))
    cta_url = db.Column(db.Text)
    metadata_json = db.Column(db.JSON)
    sort_order = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
