from __future__ import annotations

from typing import Any

from flask import jsonify, request


def api_response(payload: dict[str, Any] | list[Any], status: int = 200):
    return jsonify(payload), status


def success_response(
    *,
    message: str | None = None,
    status: int = 200,
    **payload: Any,
):
    body: dict[str, Any] = {}
    if message:
        body["message"] = message
    body.update(payload)
    return api_response(body, status=status)


def error_response(
    message: str,
    *,
    status: int = 400,
    details: Any | None = None,
    code: str | None = None,
):
    body: dict[str, Any] = {"error": message}
    if code:
        body["code"] = code
    if details is not None:
        body["details"] = details
    return api_response(body, status=status)


def items_response(items: list[Any], *, status: int = 200, **extra: Any):
    body: dict[str, Any] = {"items": items}
    body.update(extra)
    return api_response(body, status=status)


def parse_pagination_args(
    *,
    default_page: int = 1,
    default_per_page: int = 24,
    max_per_page: int = 60,
) -> tuple[int, int]:
    page = request.args.get("page", default=default_page, type=int) or default_page
    per_page = (
        request.args.get("per_page", default=default_per_page, type=int)
        or default_per_page
    )
    page = max(page, 1)
    per_page = min(max(per_page, 1), max_per_page)
    return page, per_page


def pagination_payload(*, page: int, per_page: int, total: int) -> dict[str, Any]:
    page_count = max((total + per_page - 1) // per_page, 1)
    return {
        "page": page,
        "per_page": per_page,
        "total": total,
        "page_count": page_count,
        "has_next": page < page_count,
        "has_prev": page > 1,
    }
