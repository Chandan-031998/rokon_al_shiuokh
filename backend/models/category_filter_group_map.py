from extensions import db


class CategoryFilterGroupMap(db.Model):
    __tablename__ = 'category_filter_group_map'

    category_id = db.Column(
        db.BigInteger,
        db.ForeignKey('categories.id', ondelete='cascade'),
        primary_key=True,
    )
    filter_group_id = db.Column(
        db.BigInteger,
        db.ForeignKey('filter_groups.id', ondelete='cascade'),
        primary_key=True,
    )
