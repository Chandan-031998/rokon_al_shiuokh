from __future__ import annotations

from flask import request


class ValidationError(ValueError):
    pass


def get_json_body() -> dict:
    payload = request.get_json(silent=True)
    if payload is None:
        return {}
    if not isinstance(payload, dict):
        raise ValidationError("Request body must be a JSON object.")
    return payload


def required_string(
    data: dict,
    key: str,
    *,
    label: str | None = None,
    lower: bool = False,
) -> str:
    value = (data.get(key) or "").strip()
    if not value:
        raise ValidationError(f"{label or key} is required.")
    return value.lower() if lower else value


def optional_string(
    data: dict,
    key: str,
    *,
    lower: bool = False,
) -> str | None:
    value = data.get(key)
    if value is None:
        return None
    value = str(value).strip()
    if not value:
        return None
    return value.lower() if lower else value


def integer_field(
    data: dict,
    key: str,
    *,
    required: bool = False,
    minimum: int | None = None,
    label: str | None = None,
) -> int | None:
    raw_value = data.get(key)
    if raw_value is None:
        if required:
            raise ValidationError(f"{label or key} is required.")
        return None

    if isinstance(raw_value, bool) or not isinstance(raw_value, int):
        raise ValidationError(f"{label or key} must be an integer.")

    if minimum is not None and raw_value < minimum:
        comparator = "greater than or equal to" if minimum == 0 else f"at least {minimum}"
        raise ValidationError(f"{label or key} must be {comparator}.")

    return raw_value
