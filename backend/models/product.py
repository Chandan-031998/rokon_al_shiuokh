from datetime import datetime
from urllib.parse import urlparse

from flask import current_app

from extensions import db


class Product(db.Model):
    __tablename__ = 'products'

    id = db.Column(db.BigInteger, primary_key=True)
    category_id = db.Column(db.BigInteger, db.ForeignKey('categories.id'), nullable=False)
    branch_id = db.Column(db.BigInteger, db.ForeignKey('branches.id'))
    name = db.Column(db.String(200), nullable=False)
    name_ar = db.Column(db.String(200))
    sku = db.Column(db.String(80), unique=True)
    short_description = db.Column(db.String(280))
    description = db.Column(db.Text)
    full_description = db.Column(db.Text)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    sale_price = db.Column(db.Numeric(10, 2))
    stock_qty = db.Column(db.Integer, default=0)
    pack_size = db.Column(db.String(80))
    tags = db.Column(db.Text)
    search_keywords = db.Column(db.Text)
    search_synonyms = db.Column(db.Text)
    image_url = db.Column(db.Text)
    is_featured = db.Column(db.Boolean, default=False)
    is_hidden_from_search = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    @property
    def resolved_image_url(self):
        raw_value = (self.image_url or '').strip()
        if not raw_value:
            return None

        parsed = urlparse(raw_value)
        if parsed.scheme in {'http', 'https'}:
            return raw_value

        supabase_url = (current_app.config.get('SUPABASE_URL') or '').rstrip('/')
        if not supabase_url:
            return raw_value

        if raw_value.startswith('/storage/v1/'):
            return f'{supabase_url}{raw_value}'
        if raw_value.startswith('storage/v1/'):
            return f'{supabase_url}/{raw_value}'

        bucket = (current_app.config.get('SUPABASE_STORAGE_BUCKET') or 'products').strip('/')
        if bucket:
            cleaned_path = raw_value.lstrip('/')
            return f'{supabase_url}/storage/v1/object/public/{bucket}/{cleaned_path}'

        return raw_value
