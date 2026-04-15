from __future__ import annotations

from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from services.db_compat import clear_table_columns_cache, get_table_columns


_CATEGORY_SEED = [
    ("Coffee", "القهوة", 1),
    ("Spices", "البهارات", 2),
    ("Herbs & Attar", "الأعشاب والعطور", 3),
    ("Incense", "البخور", 4),
    ("Nuts", "المكسرات", 5),
    ("Dates", "التمور", 6),
    ("Oils", "الزيوت", 7),
]

_BRANCH_SEED = [
    ("Mahayil Aseer (Main Branch)", "Mahayil Aseer", "Main branch address", "+966500000001"),
    ("Abha Branch", "Abha", "Abha branch address", "+966500000002"),
]

_PRODUCT_SEED = [
    {
        "category_name": "Coffee",
        "branch_name": "Mahayil Aseer (Main Branch)",
        "name": "Premium Arabic Coffee",
        "name_ar": "قهوة عربية فاخرة",
        "sku": "COF-001",
        "description": "Starter demo product",
        "price": Decimal("28.00"),
        "stock_qty": 100,
        "is_featured": True,
    },
    {
        "category_name": "Spices",
        "branch_name": "Abha Branch",
        "name": "Luxury Saffron Mix",
        "name_ar": "خلطة زعفران فاخرة",
        "sku": "SPI-001",
        "description": "Starter demo product",
        "price": Decimal("39.00"),
        "stock_qty": 80,
        "is_featured": True,
    },
]

_starter_catalog_checked = False


def ensure_starter_catalog_data():
    global _starter_catalog_checked
    if _starter_catalog_checked:
        return

    tables = {
        "branches": get_table_columns("branches"),
        "categories": get_table_columns("categories"),
        "products": get_table_columns("products"),
    }
    if not all(tables.values()):
        return

    changed = False
    try:
        changed |= _seed_branches()
        changed |= _seed_categories()
        changed |= _seed_products()
        if changed:
            db.session.commit()
            clear_table_columns_cache()
        _starter_catalog_checked = True
    except SQLAlchemyError:
        db.session.rollback()


def _seed_branches() -> bool:
    changed = False
    for name, city, address, phone in _BRANCH_SEED:
        exists = db.session.execute(
            text("select id from branches where name = :name limit 1"),
            {"name": name},
        ).scalar()
        if exists:
            continue

        db.session.execute(
            text(
                """
                insert into branches (name, city, address, phone, is_active)
                values (:name, :city, :address, :phone, true)
                """
            ),
            {"name": name, "city": city, "address": address, "phone": phone},
        )
        changed = True
    return changed


def _seed_categories() -> bool:
    changed = False
    for name, name_ar, sort_order in _CATEGORY_SEED:
        exists = db.session.execute(
            text("select id from categories where name = :name limit 1"),
            {"name": name},
        ).scalar()
        if exists:
            continue

        db.session.execute(
            text(
                """
                insert into categories (name, name_ar, sort_order, is_active)
                values (:name, :name_ar, :sort_order, true)
                """
            ),
            {"name": name, "name_ar": name_ar, "sort_order": sort_order},
        )
        changed = True
    return changed


def _seed_products() -> bool:
    product_columns = get_table_columns("products")
    if not {"category_id", "branch_id", "name", "price", "stock_qty", "is_featured", "is_active"} <= product_columns:
        return False

    changed = False
    for product in _PRODUCT_SEED:
        exists = db.session.execute(
            text("select id from products where sku = :sku limit 1"),
            {"sku": product["sku"]},
        ).scalar()
        if exists:
            continue

        category_id = db.session.execute(
            text("select id from categories where name = :name limit 1"),
            {"name": product["category_name"]},
        ).scalar()
        branch_id = db.session.execute(
            text("select id from branches where name = :name limit 1"),
            {"name": product["branch_name"]},
        ).scalar()
        if category_id is None or branch_id is None:
            continue

        db.session.execute(
            text(
                """
                insert into products (
                    category_id,
                    branch_id,
                    name,
                    name_ar,
                    sku,
                    description,
                    price,
                    stock_qty,
                    is_featured,
                    is_active
                )
                values (
                    :category_id,
                    :branch_id,
                    :name,
                    :name_ar,
                    :sku,
                    :description,
                    :price,
                    :stock_qty,
                    :is_featured,
                    true
                )
                """
            ),
            {
                "category_id": category_id,
                "branch_id": branch_id,
                "name": product["name"],
                "name_ar": product["name_ar"],
                "sku": product["sku"],
                "description": product["description"],
                "price": float(product["price"]),
                "stock_qty": product["stock_qty"],
                "is_featured": product["is_featured"],
            },
        )
        changed = True
    return changed
