from __future__ import annotations

from dataclasses import dataclass
from functools import wraps

from flask import g, request
from flask_jwt_extended import get_jwt_identity, verify_jwt_in_request

from models.user import User
from utils.api import error_response


GUEST_SESSION_HEADER = 'X-Guest-Session-ID'


@dataclass(frozen=True)
class CartOwner:
    user_id: int | None
    guest_session_id: str | None

    @property
    def is_authenticated(self) -> bool:
        return self.user_id is not None


@dataclass(frozen=True)
class AuthenticatedUser:
    id: int
    role: str
    email: str


def resolve_cart_owner() -> CartOwner:
    verify_jwt_in_request(optional=True)
    identity = get_jwt_identity()
    if identity is not None:
        return CartOwner(user_id=int(identity), guest_session_id=None)

    guest_session_id = (request.headers.get(GUEST_SESSION_HEADER) or '').strip()
    if guest_session_id:
        return CartOwner(user_id=None, guest_session_id=guest_session_id)

    raise ValueError('Missing guest session id')


def resolve_authenticated_user(*, required: bool = True) -> AuthenticatedUser | None:
    verify_jwt_in_request(optional=not required)
    identity = get_jwt_identity()
    if identity is None:
        return None

    user = User.query.filter_by(id=int(identity)).first()
    if not user or not user.is_active:
        return None

    resolved = AuthenticatedUser(id=user.id, role=(user.role or 'customer'), email=user.email)
    g.current_user = user
    return resolved


def admin_required(view_func):
    @wraps(view_func)
    def wrapped(*args, **kwargs):
        user = resolve_authenticated_user(required=True)
        if user is None:
            return error_response('Authentication is required.', status=401, code='auth_required')
        if user.role != 'admin':
            return error_response('Admin access is required.', status=403, code='admin_required')
        return view_func(*args, **kwargs)

    return wrapped
