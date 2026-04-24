from datetime import datetime

from extensions import db


class ProductBranchAvailability(db.Model):
    __tablename__ = 'product_branch_availability'

    id = db.Column(db.BigInteger, primary_key=True)
    product_id = db.Column(
        db.BigInteger,
        db.ForeignKey('products.id', ondelete='cascade'),
        nullable=False,
        index=True,
    )
    branch_id = db.Column(
        db.BigInteger,
        db.ForeignKey('branches.id', ondelete='cascade'),
        nullable=False,
        index=True,
    )
    is_available = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
