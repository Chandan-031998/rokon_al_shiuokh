from flask import Blueprint
from flask_jwt_extended import create_access_token, get_jwt_identity, jwt_required
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from extensions import db
from models.address import Address
from models.branch import Branch
from models.order import Order
from models.user import User
from routes.response_utils import unavailable_resource_response
from utils.api import error_response, success_response
from utils.validators import ValidationError, get_json_body, optional_string, required_string


auth_bp = Blueprint('auth', __name__)


def _serialize_user(user: User):
    addresses = Address.query.filter_by(user_id=user.id).order_by(
        Address.is_default.desc(),
        Address.created_at.desc(),
    ).all()
    latest_order = Order.query.filter_by(user_id=user.id).order_by(Order.created_at.desc()).first()
    preferred_branch = None
    if latest_order and latest_order.branch_id is not None:
        branch = Branch.query.filter_by(id=latest_order.branch_id).first()
        if branch:
            preferred_branch = {
                'id': branch.id,
                'name': branch.name,
                'city': branch.city,
                'address': branch.address,
                'phone': branch.phone,
            }

    return {
        'id': user.id,
        'full_name': user.full_name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'is_active': user.is_active,
        'addresses': [
            {
                'id': address.id,
                'label': address.label,
                'city': address.city,
                'neighborhood': address.neighborhood,
                'address_line': address.address_line,
                'is_default': address.is_default,
            }
            for address in addresses
        ],
        'preferred_branch': preferred_branch,
    }


def _auth_response(user: User, message: str, *, status: int = 200):
    token = create_access_token(identity=str(user.id))
    return success_response(
        message=message,
        status=status,
        access_token=token,
        user=_serialize_user(user),
    )


@auth_bp.post('/register')
def register():
    try:
        data = get_json_body()
        full_name = required_string(data, 'full_name', label='Full name')
        email = required_string(data, 'email', label='Email', lower=True)
        password = required_string(data, 'password', label='Password')
        phone = optional_string(data, 'phone')
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    if '@' not in email or '.' not in email.split('@')[-1]:
        return error_response('Please enter a valid email address.', status=400)
    if len(password) < 6:
        return error_response('Password must be at least 6 characters long.', status=400)

    try:
        existing = User.query.filter_by(email=email).first()
        if existing:
            return error_response('An account already exists for this email.', status=409)

        user = User(full_name=full_name, email=email, phone=phone)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
    except IntegrityError as exc:
        db.session.rollback()
        details = str(getattr(exc, 'orig', exc)).lower()
        if 'phone' in details:
            return error_response('This phone number is already in use.', status=409)
        if 'email' in details:
            return error_response('An account already exists for this email.', status=409)
        return error_response('Unable to create the account right now.', status=409)
    except SQLAlchemyError:
        db.session.rollback()
        return unavailable_resource_response('Authentication')

    return _auth_response(user, 'Account created successfully.', status=201)


@auth_bp.post('/login')
def login():
    try:
        data = get_json_body()
        email = required_string(data, 'email', label='Email', lower=True)
        password = required_string(data, 'password', label='Password')
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    try:
        user = User.query.filter_by(email=email).first()
        if not user or not user.check_password(password):
            return error_response('Invalid email or password.', status=401)
        if not user.is_active:
            return error_response('This account is inactive.', status=403)
    except SQLAlchemyError:
        db.session.rollback()
        return unavailable_resource_response('Authentication')

    return _auth_response(user, 'Login successful.')


@auth_bp.get('/profile')
@jwt_required()
def profile():
    identity = get_jwt_identity()

    try:
        user = User.query.filter_by(id=int(identity)).first()
        if not user:
            return error_response('User profile not found.', status=404)
    except SQLAlchemyError:
        db.session.rollback()
        return unavailable_resource_response('Authentication')

    return success_response(user=_serialize_user(user))


@auth_bp.patch('/profile')
@jwt_required()
def update_profile():
    identity = get_jwt_identity()
    try:
        data = get_json_body()
        full_name = required_string(data, 'full_name', label='Full name')
        phone = optional_string(data, 'phone')
    except ValidationError as exc:
        return error_response(str(exc), status=400)

    if phone is not None and len(phone) < 8:
        return error_response('Please enter a valid phone number.', status=400)

    try:
        user = User.query.filter_by(id=int(identity)).first()
        if not user:
            return error_response('User profile not found.', status=404)

        existing_phone = None
        if phone:
            existing_phone = User.query.filter(User.phone == phone, User.id != user.id).first()
        if existing_phone:
            return error_response('This phone number is already in use.', status=409)

        user.full_name = full_name
        user.phone = phone
        db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()
        return unavailable_resource_response('Authentication')

    return success_response(
        message='Profile updated successfully.',
        user=_serialize_user(user),
    )
