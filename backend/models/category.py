from datetime import datetime
from extensions import db


class Category(db.Model):
    __tablename__ = 'categories'

    id = db.Column(db.BigInteger, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    name_en = db.Column(db.String(120))
    name_ar = db.Column(db.String(120))
    image_url = db.Column(db.Text)
    icon_key = db.Column(db.String(80))
    sort_order = db.Column(db.Integer, default=0)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def localized_name(self, language: str | None = None) -> str:
        normalized = (language or 'en').strip().lower()
        if normalized == 'ar' and (self.name_ar or '').strip():
            return self.name_ar.strip()
        return (self.name_en or self.name or '').strip()
