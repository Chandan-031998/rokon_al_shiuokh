from flask import Flask, request
from flask_cors import CORS
from flask_jwt_extended.exceptions import JWTExtendedException
from sqlalchemy.exc import SQLAlchemyError

from config import Config, is_allowed_cors_origin
from extensions import db, migrate, jwt
from models.user import User
from routes.auth_routes import auth_bp
from routes.category_routes import category_bp
from routes.product_routes import product_bp
from routes.cart_routes import cart_bp
from routes.order_routes import order_bp
from routes.branch_routes import branch_bp
from routes.admin_routes import admin_bp
from routes.offer_routes import offer_bp
from routes.upload_routes import upload_bp
from routes.content_routes import content_bp
from routes.review_routes import review_bp
from routes.wishlist_routes import wishlist_bp
from routes.discovery_routes import discovery_bp
from routes.admin_discovery_routes import admin_discovery_bp
from services.catalog_seed import ensure_starter_catalog_data
from utils.api import error_response, success_response


def create_app():
    print('Flask app starting...', flush=True)
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(
        app,
        resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}},
        supports_credentials=False,
        allow_headers=app.config["CORS_ALLOW_HEADERS"],
        methods=app.config["CORS_METHODS"],
        vary_header=True,
        automatic_options=True,
    )

    @app.after_request
    def apply_cors_headers(response):
        origin = request.headers.get('Origin', '').strip()
        if request.path.startswith('/api/') and is_allowed_cors_origin(
            origin, app.config.get('CORS_ORIGINS')
        ):
            response.headers['Access-Control-Allow-Origin'] = origin
            response.headers['Vary'] = 'Origin'
            response.headers['Access-Control-Allow-Headers'] = ', '.join(
                app.config['CORS_ALLOW_HEADERS']
            )
            response.headers['Access-Control-Allow-Methods'] = ', '.join(
                app.config['CORS_METHODS']
            )
            response.headers['Access-Control-Max-Age'] = '600'
        return response
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)

    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(category_bp, url_prefix='/api/categories')
    app.register_blueprint(product_bp, url_prefix='/api/products')
    app.register_blueprint(cart_bp, url_prefix='/api/cart')
    app.register_blueprint(order_bp, url_prefix='/api/orders')
    app.register_blueprint(branch_bp, url_prefix='/api/branches')
    app.register_blueprint(offer_bp, url_prefix='/api/offers')
    app.register_blueprint(upload_bp, url_prefix='/api/uploads')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    app.register_blueprint(content_bp, url_prefix='/api/content')
    app.register_blueprint(review_bp, url_prefix='/api/reviews')
    app.register_blueprint(wishlist_bp, url_prefix='/api/wishlist')
    app.register_blueprint(discovery_bp, url_prefix='/api/discovery')
    app.register_blueprint(admin_discovery_bp, url_prefix='/api/admin/discovery')

    @jwt.unauthorized_loader
    def handle_missing_jwt(reason):
        return error_response(
            'Authentication is required.',
            status=401,
            code='auth_required',
            details=reason,
        )

    @jwt.invalid_token_loader
    def handle_invalid_jwt(reason):
        return error_response(
            'The session token is invalid.',
            status=401,
            code='invalid_token',
            details=reason,
        )

    @jwt.expired_token_loader
    def handle_expired_jwt(_jwt_header, _jwt_payload):
        return error_response(
            'Your session has expired. Please sign in again.',
            status=401,
            code='token_expired',
        )

    @jwt.revoked_token_loader
    def handle_revoked_jwt(_jwt_header, _jwt_payload):
        return error_response(
            'The session token has been revoked.',
            status=401,
            code='token_revoked',
        )

    @app.errorhandler(404)
    def handle_not_found(_error):
        return error_response('The requested API resource was not found.', status=404)

    @app.errorhandler(405)
    def handle_method_not_allowed(_error):
        return error_response('The HTTP method is not allowed for this endpoint.', status=405)

    @app.errorhandler(SQLAlchemyError)
    def handle_sqlalchemy_error(error):
        db.session.rollback()
        app.logger.exception('Unhandled database error: %s', error)
        return error_response(
            'A database error occurred while processing the request.',
            status=500,
            code='database_error',
        )

    @app.errorhandler(JWTExtendedException)
    def handle_jwt_error(error):
        return error_response(str(error), status=401, code='jwt_error')

    @app.errorhandler(Exception)
    def handle_unexpected_error(error):
        app.logger.exception('Unhandled application error: %s', error)
        return error_response(
            'An unexpected server error occurred.',
            status=500,
            code='internal_server_error',
        )

    @app.get('/')
    def index():
        return 'App is running'

    with app.app_context():
        _run_startup_tasks(app)

    return app


def _run_startup_tasks(app: Flask):
    database_url = (app.config.get('SQLALCHEMY_DATABASE_URI') or '').strip()
    if not database_url:
        print('Startup Error: DATABASE_URL is not set. Skipping database bootstrap.', flush=True)
        return

    try:
        _bootstrap_admin_user(app)
        ensure_starter_catalog_data()
    except Exception as error:  # pragma: no cover - startup is environment specific
        db.session.rollback()
        print(f'Startup Error: {error}', flush=True)
        app.logger.exception('Startup initialization failed: %s', error)


def _bootstrap_admin_user(app: Flask):
    email = (app.config.get('ADMIN_BOOTSTRAP_EMAIL') or '').strip().lower()
    password = (app.config.get('ADMIN_BOOTSTRAP_PASSWORD') or '').strip()
    full_name = (app.config.get('ADMIN_BOOTSTRAP_NAME') or 'Rokon Admin').strip()
    if not email or not password:
        return

    try:
        existing_admin = User.query.filter_by(email=email).first()
        if existing_admin:
            if existing_admin.role != 'admin':
                existing_admin.role = 'admin'
                db.session.commit()
            return

        user = User(
            full_name=full_name,
            email=email,
            role='admin',
            is_active=True,
        )
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        app.logger.info('Bootstrapped admin user: %s', email)
    except Exception as error:  # pragma: no cover - bootstrap is environment specific
        db.session.rollback()
        app.logger.warning('Unable to bootstrap admin user: %s', error)


app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
