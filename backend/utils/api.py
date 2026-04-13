from __future__ import annotations

from typing import Any

from flask import jsonify


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
