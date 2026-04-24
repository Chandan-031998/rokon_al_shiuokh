from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from flask import Blueprint, current_app, request

from services.storage_service import StorageConfigurationError, upload_public_file
from utils.api import error_response, success_response
from utils.auth import admin_required

upload_bp = Blueprint('uploads', __name__)

_MAX_UPLOAD_BYTES = 5 * 1024 * 1024
_SUPPORTED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}
_SUPPORTED_CONTENT_TYPES = {'image/jpeg', 'image/png', 'image/webp'}


@upload_bp.post('/product-image')
@admin_required
def upload_product_image():
    file = request.files.get('file')
    if file is None or not file.filename:
        return error_response('Image file is required.', status=400)

    file_bytes = file.read()
    if not file_bytes:
        return error_response('Uploaded file is empty.', status=400)
    if len(file_bytes) > _MAX_UPLOAD_BYTES:
        return error_response('Image size must be 5 MB or smaller.', status=400)

    extension = Path(file.filename).suffix.lower()
    if extension not in _SUPPORTED_EXTENSIONS:
        return error_response('Only JPG, PNG, and WEBP images are supported.', status=400)

    content_type = (file.mimetype or '').lower()
    if content_type not in _SUPPORTED_CONTENT_TYPES:
        return error_response('Invalid image content type.', status=400)

    storage_path = f'products/{uuid4().hex}{extension}'
    try:
        public_url = upload_public_file(
            path=storage_path,
            file_bytes=file_bytes,
            content_type=content_type,
        )
    except StorageConfigurationError as exc:
        current_app.logger.exception('Product image upload configuration error: %s', exc)
        return error_response(str(exc), status=500, code='storage_not_configured')
    except Exception as exc:  # pragma: no cover - external storage failures
        current_app.logger.exception('Product image upload failed: %s', exc)
        message = 'Unable to upload the product image right now.'
        error_code = 'upload_failed'
        details = str(exc)
        if 'row-level security policy' in details.lower():
            message = (
                'Supabase Storage rejected the upload. Use a service-role key or '
                'allow uploads to the products bucket.'
            )
            error_code = 'storage_permission_denied'
        return error_response(
            message,
            status=500,
            code=error_code,
            details=details,
        )

    return success_response(
        message='Image uploaded successfully.',
        url=public_url,
        path=storage_path,
    )
