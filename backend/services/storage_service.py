from __future__ import annotations

from functools import lru_cache
import base64
import json

from flask import current_app
from supabase import Client, create_client


class StorageConfigurationError(RuntimeError):
    pass


def _jwt_role(token: str) -> str | None:
    try:
        payload = token.split('.')[1]
        padding = '=' * (-len(payload) % 4)
        decoded = json.loads(base64.urlsafe_b64decode(payload + padding))
        return decoded.get('role')
    except Exception:
        return None


@lru_cache(maxsize=1)
def _get_client() -> Client:
    supabase_url = (current_app.config.get('SUPABASE_URL') or '').strip()
    service_key = (current_app.config.get('SUPABASE_SERVICE_KEY') or '').strip()
    if not supabase_url or not service_key:
        raise StorageConfigurationError(
            'SUPABASE_URL and SUPABASE_SERVICE_KEY must be configured for uploads.',
        )
    if _jwt_role(service_key) != 'service_role':
        current_app.logger.warning(
            'SUPABASE_SERVICE_KEY is not a service_role key; uploads depend on bucket policies.',
        )
    return create_client(supabase_url, service_key)


def upload_public_file(*, path: str, file_bytes: bytes, content_type: str) -> str:
    bucket = (current_app.config.get('SUPABASE_STORAGE_BUCKET') or 'products').strip()

    client = _get_client()
    bucket_client = client.storage.from_(bucket)
    bucket_client.upload(
        path=path,
        file=file_bytes,
        file_options={
            'content-type': content_type,
            'x-upsert': 'true',
        },
    )
    public_url = bucket_client.get_public_url(path)
    if not public_url:
        raise RuntimeError('Unable to resolve uploaded file URL.')
    return public_url.rstrip('?')
