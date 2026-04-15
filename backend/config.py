import os
import re
from pathlib import Path
from urllib.parse import quote

from dotenv import load_dotenv

_BACKEND_DIR = Path(__file__).resolve().parent
load_dotenv(_BACKEND_DIR / '.env')


def _normalize_database_url(raw_url: str | None):
    if not raw_url:
        return raw_url

    if '://' not in raw_url or '@' not in raw_url:
        return raw_url

    scheme, remainder = raw_url.split('://', 1)
    credentials, host_part = remainder.rsplit('@', 1)
    if ':' not in credentials:
        return raw_url

    username, password = credentials.split(':', 1)
    encoded_password = quote(password, safe='')

    return f'{scheme}://{username}:{encoded_password}@{host_part}'


_LOCAL_DEV_ORIGIN_PATTERNS = [
    r"^https?://localhost(?::\d+)?$",
    r"^https?://127\.0\.0\.1(?::\d+)?$",
    r"^https?://0\.0\.0\.0(?::\d+)?$",
    r"^https?://192\.168\.\d+\.\d+(?::\d+)?$",
    r"^https?://10\.\d+\.\d+\.\d+(?::\d+)?$",
    r"^https?://172\.(1[6-9]|2\d|3[0-1])\.\d+\.\d+(?::\d+)?$",
]

_PRODUCTION_ORIGIN_PATTERNS = [
    r"^https?://rokonalshiuokh\.com$",
    r"^https?://www\.rokonalshiuokh\.com$",
]


def _build_cors_origins(raw_value: str | None):
    configured_values = []
    if raw_value:
        configured_values = [
            value.strip()
            for value in raw_value.split(",")
            if value.strip() and value.strip() != "*"
        ]

    origins = [*configured_values]
    origins.extend(_LOCAL_DEV_ORIGIN_PATTERNS)
    origins.extend(_PRODUCTION_ORIGIN_PATTERNS)
    return origins


def is_allowed_cors_origin(origin: str | None, allowed_origins: list[str] | None):
    if not origin:
        return False

    for allowed in allowed_origins or []:
        candidate = (allowed or '').strip()
        if not candidate:
            continue
        if candidate == origin:
            return True
        try:
            if re.match(candidate, origin):
                return True
        except re.error:
            continue
    return False


class Config:
    SECRET_KEY = os.getenv('SECRET_KEY', 'dev-secret')
    JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', 'jwt-dev-secret')
    SQLALCHEMY_DATABASE_URI = _normalize_database_url(os.getenv('DATABASE_URL'))
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JSON_SORT_KEYS = False
    PROPAGATE_EXCEPTIONS = False
    CORS_ORIGINS = _build_cors_origins(os.getenv('CORS_ORIGINS'))
    CORS_ALLOW_HEADERS = [
        'Content-Type',
        'Authorization',
        'X-Guest-Session-ID',
    ]
    CORS_METHODS = ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS']
    SUPABASE_URL = os.getenv('SUPABASE_URL', '')
    SUPABASE_ANON_KEY = os.getenv('SUPABASE_ANON_KEY', '')
    SUPABASE_SERVICE_KEY = os.getenv('SUPABASE_SERVICE_KEY', '')
    SUPABASE_STORAGE_BUCKET = os.getenv('SUPABASE_STORAGE_BUCKET', 'products')
    ADMIN_BOOTSTRAP_EMAIL = os.getenv('ADMIN_BOOTSTRAP_EMAIL', '')
    ADMIN_BOOTSTRAP_PASSWORD = os.getenv('ADMIN_BOOTSTRAP_PASSWORD', '')
    ADMIN_BOOTSTRAP_NAME = os.getenv('ADMIN_BOOTSTRAP_NAME', 'Rokon Admin')
