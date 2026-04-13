from extensions import db


class OrderItem(db.Model):
    __tablename__ = 'order_items'

    id = db.Column(db.BigInteger, primary_key=True)
    order_id = db.Column(db.BigInteger, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.BigInteger, db.ForeignKey('products.id'), nullable=False)
    product_name = db.Column(db.String(200), nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    quantity = db.Column(db.Integer, nullable=False, default=1)
    line_total = db.Column(db.Numeric(10, 2), nullable=False, default=0)
