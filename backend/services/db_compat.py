from __future__ import annotations

from functools import lru_cache

from sqlalchemy import inspect
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import load_only

from extensions import db


@lru_cache(maxsize=64)
def _cached_table_columns(database_url: str, table_name: str) -> tuple[str, ...]:
    inspector = inspect(db.engine)
    return tuple(column["name"] for column in inspector.get_columns(table_name))


def get_table_columns(table_name: str) -> set[str]:
    database_url = str(db.engine.url)
    try:
        columns = set(_cached_table_columns(database_url, table_name))
        if columns:
            return columns
        clear_table_columns_cache()
        return set(_cached_table_columns(database_url, table_name))
    except SQLAlchemyError:
        return set()


def clear_table_columns_cache():
    _cached_table_columns.cache_clear()


def column_exists(table_name: str, column_name: str) -> bool:
    return column_name in get_table_columns(table_name)


def load_only_existing(model, table_name: str, field_names: list[str]):
    columns = get_table_columns(table_name)
    attrs = [getattr(model, name) for name in field_names if name in columns]
    if not attrs:
        return None
    return load_only(*attrs)
