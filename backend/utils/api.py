from __future__ import annotations

from typing import Any

from flask import jsonify, make_response


def api_response(
    payload: dict[str, Any] | list[Any],
    status: int = 200,
    *,
    cache_seconds: int | None = None,
):
    response = make_response(jsonify(payload), status)
    if cache_seconds is not None:
        response.headers["Cache-Control"] = (
            f"public, max-age={cache_seconds}, s-maxage={cache_seconds}"
        )
    return response


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
