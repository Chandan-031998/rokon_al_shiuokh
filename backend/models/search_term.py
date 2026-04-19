from datetime import datetime

from extensions import db


class SearchTerm(db.Model):
    __tablename__ = 'search_terms'

    id = db.Column(db.BigInteger, primary_key=True)
    term = db.Column(db.String(160), nullable=False, unique=True)
    term_type = db.Column(db.String(30), nullable=False, default='popular')
    synonyms = db.Column(db.Text)
    linked_category_id = db.Column(
        db.BigInteger,
        db.ForeignKey('categories.id', ondelete='set null'),
    )
    linked_product_id = db.Column(
        db.BigInteger,
        db.ForeignKey('products.id', ondelete='set null'),
    )
    sort_order = db.Column(db.Integer, nullable=False, default=0)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
