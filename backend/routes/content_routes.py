from __future__ import annotations

from datetime import datetime

from flask import Blueprint, request

from models.cms_page import CmsPage
from models.faq import Faq
from models.offer import Offer
from models.support_setting import SupportSetting
from utils.api import items_response, success_response


content_bp = Blueprint('content', __name__)


@content_bp.get('/pages')
def list_content_pages():
    section = (request.args.get('section') or '').strip().lower()
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower()
    query = CmsPage.query.filter_by(is_active=True)
    if section:
        query = query.filter_by(section=section)
    if region_code:
        query = query.filter(
            CmsPage.region_code.is_(None) | (CmsPage.region_code == region_code)
        )
    rows = query.order_by(CmsPage.section.asc(), CmsPage.sort_order.asc(), CmsPage.id.asc()).all()
    return items_response(
        [_serialize_cms_page(row, language=language) for row in rows],
        total=len(rows),
    )


@content_bp.get('/pages/<string:slug>')
def get_content_page(slug: str):
    normalized_slug = slug.strip().lower()
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower()
    query = CmsPage.query.filter_by(slug=normalized_slug, is_active=True)
    if region_code:
        query = query.filter(
            CmsPage.region_code.is_(None) | (CmsPage.region_code == region_code)
        )
    row = query.order_by(CmsPage.region_code.desc().nullslast()).first()
    if not row:
        return success_response(page=None)
    return success_response(page=_serialize_cms_page(row, language=language))


@content_bp.get('/faqs')
def list_faqs():
    language = (request.args.get('language') or 'en').strip().lower()
    rows = Faq.query.filter_by(is_active=True).order_by(Faq.sort_order.asc(), Faq.id.asc()).all()
    return items_response(
        [_serialize_faq(row, language=language) for row in rows],
        total=len(rows),
    )


@content_bp.get('/support')
def get_support_settings():
    language = (request.args.get('language') or 'en').strip().lower()
    settings = SupportSetting.query.order_by(SupportSetting.id.asc()).first()
    return success_response(settings=_serialize_support_settings(settings, language=language))


@content_bp.get('/offers')
def list_active_offers():
    now = datetime.utcnow()
    language = (request.args.get('language') or 'en').strip().lower()
    region_code = (request.args.get('region_code') or '').strip().lower()
    query = (
        Offer.query.filter_by(is_active=True)
        .filter((Offer.starts_at.is_(None)) | (Offer.starts_at <= now))
        .filter((Offer.ends_at.is_(None)) | (Offer.ends_at >= now))
    )
    if region_code:
        query = query.filter(
            Offer.region_code.is_(None) | (Offer.region_code == region_code)
        )
    rows = query.order_by(Offer.created_at.desc()).all()
    return items_response(
        [_serialize_offer(row, language=language) for row in rows],
        total=len(rows),
    )


def _localized_value(language: str, english_value, arabic_value):
    if language == 'ar' and (arabic_value or '').strip():
        return arabic_value
    return english_value


def _localized_metadata(page: CmsPage, language: str) -> dict:
    metadata = dict(page.metadata_json or {})
    if language != 'ar':
        return metadata

    localized_pairs = (
        ('eyebrow', 'eyebrow_ar'),
        ('secondary_label', 'secondary_label_ar'),
        ('metric', 'metric_ar'),
        ('cta_label', 'cta_label_ar'),
        ('title', 'title_ar'),
        ('excerpt', 'excerpt_ar'),
        ('body', 'body_ar'),
    )
    for key, localized_key in localized_pairs:
        localized_value = metadata.get(localized_key)
        if isinstance(localized_value, str) and localized_value.strip():
            metadata[key] = localized_value.strip()
    return metadata


def _serialize_cms_page(page: CmsPage, *, language: str = 'en'):
    title = _localized_value(language, page.title_en or page.title, page.title_ar)
    excerpt = _localized_value(
        language,
        page.excerpt_en or page.excerpt,
        page.excerpt_ar,
    )
    body = _localized_value(language, page.body_en or page.body, page.body_ar)
    cta_label = _localized_value(
        language,
        page.cta_label,
        (page.metadata_json or {}).get('cta_label_ar'),
    )
    return {
        'id': page.id,
        'slug': page.slug,
        'title': title,
        'title_en': page.title_en or page.title,
        'title_ar': page.title_ar,
        'section': page.section,
        'excerpt': excerpt,
        'excerpt_en': page.excerpt_en or page.excerpt,
        'excerpt_ar': page.excerpt_ar,
        'body': body,
        'body_en': page.body_en or page.body,
        'body_ar': page.body_ar,
        'image_url': page.image_url,
        'cta_label': cta_label,
        'cta_url': page.cta_url,
        'region_code': page.region_code,
        'metadata_json': _localized_metadata(page, language),
        'sort_order': page.sort_order,
        'is_active': page.is_active,
        'created_at': page.created_at.isoformat() if page.created_at else None,
        'updated_at': page.updated_at.isoformat() if page.updated_at else None,
    }


def _serialize_faq(faq: Faq, *, language: str = 'en'):
    return {
        'id': faq.id,
        'question': _localized_value(language, faq.question, faq.question_ar),
        'question_ar': faq.question_ar,
        'answer': _localized_value(language, faq.answer, faq.answer_ar),
        'answer_ar': faq.answer_ar,
        'sort_order': faq.sort_order,
        'is_active': faq.is_active,
        'created_at': faq.created_at.isoformat() if faq.created_at else None,
        'updated_at': faq.updated_at.isoformat() if faq.updated_at else None,
    }


def _serialize_support_settings(settings: SupportSetting | None, *, language: str = 'en'):
    if settings is None:
        payment_cod_label = (
            'الدفع عند الاستلام' if language == 'ar' else 'Cash on Delivery'
        )
        payment_card_label = 'الدفع بالبطاقة' if language == 'ar' else 'Card Payment'
        payment_bank_label = (
            'التحويل البنكي' if language == 'ar' else 'Bank Transfer'
        )
        return {
            'contact_email': None,
            'contact_phone': None,
            'contact_address': None,
            'contact_address_ar': None,
            'support_hours': None,
            'support_hours_ar': None,
            'whatsapp_number': None,
            'whatsapp_label': None,
            'whatsapp_label_ar': None,
            'payment_cod_enabled': True,
            'payment_card_enabled': False,
            'payment_bank_transfer_enabled': False,
            'payment_cod_label': payment_cod_label,
            'payment_card_label': payment_card_label,
            'payment_bank_transfer_label': payment_bank_label,
            'payment_checkout_notice': None,
            'payment_methods': [
                {
                    'code': 'cod',
                    'label': payment_cod_label,
                    'enabled': True,
                },
            ],
            'facebook_url': None,
            'instagram_url': None,
            'twitter_url': None,
            'tiktok_url': None,
            'snapchat_url': None,
            'youtube_url': None,
        }
    return {
        'contact_email': settings.contact_email,
        'contact_phone': settings.contact_phone,
        'contact_address': _localized_value(
            language,
            settings.contact_address,
            settings.contact_address_ar,
        ),
        'contact_address_ar': settings.contact_address_ar,
        'support_hours': _localized_value(
            language,
            settings.support_hours,
            settings.support_hours_ar,
        ),
        'support_hours_ar': settings.support_hours_ar,
        'whatsapp_number': settings.whatsapp_number,
        'whatsapp_label': _localized_value(
            language,
            settings.whatsapp_label,
            settings.whatsapp_label_ar,
        ),
        'whatsapp_label_ar': settings.whatsapp_label_ar,
        'payment_cod_enabled': bool(settings.payment_cod_enabled),
        'payment_card_enabled': bool(settings.payment_card_enabled),
        'payment_bank_transfer_enabled': bool(settings.payment_bank_transfer_enabled),
        'payment_cod_label': settings.payment_cod_label or 'Cash on Delivery',
        'payment_card_label': settings.payment_card_label or 'Card Payment',
        'payment_bank_transfer_label': settings.payment_bank_transfer_label or 'Bank Transfer',
        'payment_checkout_notice': settings.payment_checkout_notice,
        'payment_methods': _serialize_payment_methods(settings, language=language),
        'facebook_url': settings.facebook_url,
        'instagram_url': settings.instagram_url,
        'twitter_url': settings.twitter_url,
        'tiktok_url': settings.tiktok_url,
        'snapchat_url': settings.snapchat_url,
        'youtube_url': settings.youtube_url,
    }


def _serialize_offer(offer: Offer, *, language: str = 'en'):
    return {
        'id': offer.id,
        'title': _localized_value(language, offer.title_en or offer.title, offer.title_ar),
        'title_en': offer.title_en or offer.title,
        'title_ar': offer.title_ar,
        'subtitle': _localized_value(
            language,
            offer.subtitle_en or offer.subtitle,
            offer.subtitle_ar,
        ),
        'subtitle_en': offer.subtitle_en or offer.subtitle,
        'subtitle_ar': offer.subtitle_ar,
        'description': _localized_value(
            language,
            offer.description_en or offer.description,
            offer.description_ar,
        ),
        'description_en': offer.description_en or offer.description,
        'description_ar': offer.description_ar,
        'banner_url': offer.banner_url,
        'region_code': offer.region_code,
        'currency_code': offer.currency_code,
        'discount_type': offer.discount_type,
        'discount_value': float(offer.discount_value or 0),
        'product_id': offer.product_id,
        'category_id': offer.category_id,
        'branch_id': offer.branch_id,
        'starts_at': offer.starts_at.isoformat() if offer.starts_at else None,
        'ends_at': offer.ends_at.isoformat() if offer.ends_at else None,
        'is_active': offer.is_active,
        'created_at': offer.created_at.isoformat() if offer.created_at else None,
    }


def _serialize_payment_methods(
    settings: SupportSetting,
    *,
    language: str = 'en',
) -> list[dict]:
    default_cod_label = 'الدفع عند الاستلام' if language == 'ar' else 'Cash on Delivery'
    default_card_label = 'الدفع بالبطاقة' if language == 'ar' else 'Card Payment'
    default_bank_label = 'التحويل البنكي' if language == 'ar' else 'Bank Transfer'
    return [
        {
            'code': 'cod',
            'label': settings.payment_cod_label or default_cod_label,
            'enabled': bool(settings.payment_cod_enabled),
        },
        {
            'code': 'card',
            'label': settings.payment_card_label or default_card_label,
            'enabled': bool(settings.payment_card_enabled),
        },
        {
            'code': 'bank_transfer',
            'label': settings.payment_bank_transfer_label or default_bank_label,
            'enabled': bool(settings.payment_bank_transfer_enabled),
        },
    ]
