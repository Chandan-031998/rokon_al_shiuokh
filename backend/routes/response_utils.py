from __future__ import annotations

from flask import current_app
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from utils.api import api_response, error_response, items_response


def empty_collection_response(resource_name: str):
    return items_response(
        [],
        warning=f"{resource_name} data is unavailable until the database schema is ready.",
        todo="Apply sql/rokon_al_shiuokh_schema.sql to Supabase and seed the starter data.",
    )


def empty_array_response(resource_name: str):
    current_app.logger.warning(
        "%s data is unavailable until the database schema is ready.",
        resource_name,
    )
    return api_response([])


def unavailable_resource_response(resource_name: str):
    return error_response(
        f"{resource_name} is unavailable right now.",
        status=503,
        code="resource_unavailable",
        details={
            "todo": "Finish the database setup before enabling this endpoint for production use.",
        },
    )


def handle_database_error(exc: SQLAlchemyError, resource_name: str):
    db.session.rollback()
    current_app.logger.warning("Database error while loading %s: %s", resource_name, exc)
    return empty_collection_response(resource_name)
