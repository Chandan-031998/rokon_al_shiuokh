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
    name_en = db.Column(db.String(200))
    name_ar = db.Column(db.String(200))
    sku = db.Column(db.String(80), unique=True)
    short_description = db.Column(db.String(280))
    short_description_en = db.Column(db.String(280))
    short_description_ar = db.Column(db.String(280))
    description = db.Column(db.Text)
    full_description = db.Column(db.Text)
    full_description_en = db.Column(db.Text)
    full_description_ar = db.Column(db.Text)
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
    images = db.relationship(
        'ProductImage',
        backref='product',
        lazy='selectin',
        cascade='all, delete-orphan',
        order_by='ProductImage.sort_order.asc(), ProductImage.id.asc()',
    )
    region_prices = db.relationship(
        'ProductRegionPrice',
        backref='product',
        lazy='selectin',
        cascade='all, delete-orphan',
        order_by='ProductRegionPrice.region_code.asc(), ProductRegionPrice.id.asc()',
    )
    branch_availability = db.relationship(
        'ProductBranchAvailability',
        backref='product',
        lazy='selectin',
        cascade='all, delete-orphan',
        order_by='ProductBranchAvailability.branch_id.asc(), ProductBranchAvailability.id.asc()',
    )

    def resolve_storage_url(self, raw_value: str | None):
        raw_value = (raw_value or '').strip()
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

    @property
    def resolved_images(self):
        images = []
        for image in self.images or []:
            resolved_url = self.resolve_storage_url(image.image_url)
            if not resolved_url:
                continue
            images.append(
                {
                    'id': image.id,
                    'product_id': image.product_id,
                    'image_url': resolved_url,
                    'sort_order': image.sort_order or 0,
                    'is_primary': bool(image.is_primary),
                    'created_at': image.created_at.isoformat() if image.created_at else None,
                }
            )
        return images

    @property
    def resolved_image_url(self):
        primary_image = next(
            (image for image in self.resolved_images if image['is_primary']),
            None,
        )
        if primary_image is not None:
            return primary_image['image_url']
        return self.resolve_storage_url(self.image_url)

    def localized_name(self, language: str | None = None):
        language = (language or 'en').strip().lower()
        if language == 'ar' and (self.name_ar or '').strip():
            return self.name_ar
        return (self.name_en or self.name or '').strip()

    def localized_short_description(self, language: str | None = None):
        language = (language or 'en').strip().lower()
        if language == 'ar' and (self.short_description_ar or '').strip():
            return self.short_description_ar
        return (
            (self.short_description_en or self.short_description or '').strip()
            or None
        )

    def localized_full_description(self, language: str | None = None):
        language = (language or 'en').strip().lower()
        if language == 'ar' and (self.full_description_ar or '').strip():
            return self.full_description_ar
        return (
            (self.full_description_en or self.full_description or '').strip()
            or None
        )

    def region_price_row(self, region_code: str | None = None):
        normalized = (region_code or '').strip().lower()
        if not normalized:
            return None
        for row in self.region_prices or []:
            if (row.region_code or '').strip().lower() == normalized:
                return row
        return None

    def visible_in_region(self, region_code: str | None = None):
        row = self.region_price_row(region_code)
        if row is None:
            return True
        return bool(row.is_visible)

    def effective_price(self, region_code: str | None = None):
        row = self.region_price_row(region_code)
        if row is None or row.price is None:
            return self.price
        return row.price

    def effective_sale_price(self, region_code: str | None = None):
        row = self.region_price_row(region_code)
        if row is None:
            return self.sale_price
        return row.sale_price

    def available_branch_ids(self):
        branch_ids = [
            row.branch_id
            for row in (self.branch_availability or [])
            if bool(row.is_available) and row.branch_id is not None
        ]
        if branch_ids:
            return branch_ids
        if self.branch_id is not None:
            return [self.branch_id]
        return []

    def is_available_for_branch(self, branch_id: int | None):
        if branch_id is None:
            return True
        available_branch_ids = self.available_branch_ids()
        if available_branch_ids:
            return branch_id in available_branch_ids
        return self.branch_id is None or self.branch_id == branch_id
