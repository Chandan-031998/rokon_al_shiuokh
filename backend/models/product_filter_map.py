from extensions import db


class ProductFilterMap(db.Model):
    __tablename__ = 'product_filter_map'

    product_id = db.Column(
        db.BigInteger,
        db.ForeignKey('products.id', ondelete='cascade'),
        primary_key=True,
    )
    filter_value_id = db.Column(
        db.BigInteger,
        db.ForeignKey('filter_values.id', ondelete='cascade'),
        primary_key=True,
    )
