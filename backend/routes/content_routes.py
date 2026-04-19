from __future__ import annotations

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
    query = CmsPage.query.filter_by(is_active=True)
    if section:
        query = query.filter_by(section=section)
    rows = query.order_by(CmsPage.section.asc(), CmsPage.sort_order.asc(), CmsPage.id.asc()).all()
    return items_response([_serialize_cms_page(row) for row in rows], total=len(rows))


@content_bp.get('/pages/<string:slug>')
def get_content_page(slug: str):
    row = CmsPage.query.filter_by(slug=slug.strip().lower(), is_active=True).first()
    if not row:
        return success_response(page=None)
    return success_response(page=_serialize_cms_page(row))


@content_bp.get('/faqs')
def list_faqs():
    rows = Faq.query.filter_by(is_active=True).order_by(Faq.sort_order.asc(), Faq.id.asc()).all()
    return items_response([_serialize_faq(row) for row in rows], total=len(rows))


@content_bp.get('/support')
def get_support_settings():
    settings = SupportSetting.query.order_by(SupportSetting.id.asc()).first()
    return success_response(settings=_serialize_support_settings(settings))


@content_bp.get('/offers')
def list_active_offers():
    rows = Offer.query.filter_by(is_active=True).order_by(Offer.created_at.desc()).all()
    return items_response([_serialize_offer(row) for row in rows], total=len(rows))


def _serialize_cms_page(page: CmsPage):
    return {
        'id': page.id,
        'slug': page.slug,
        'title': page.title,
        'section': page.section,
        'excerpt': page.excerpt,
        'body': page.body,
        'image_url': page.image_url,
        'cta_label': page.cta_label,
        'cta_url': page.cta_url,
        'metadata_json': page.metadata_json or {},
        'sort_order': page.sort_order,
        'is_active': page.is_active,
        'created_at': page.created_at.isoformat() if page.created_at else None,
        'updated_at': page.updated_at.isoformat() if page.updated_at else None,
    }


def _serialize_faq(faq: Faq):
    return {
        'id': faq.id,
        'question': faq.question,
        'answer': faq.answer,
        'sort_order': faq.sort_order,
        'is_active': faq.is_active,
        'created_at': faq.created_at.isoformat() if faq.created_at else None,
        'updated_at': faq.updated_at.isoformat() if faq.updated_at else None,
    }


def _serialize_support_settings(settings: SupportSetting | None):
    if settings is None:
        return {
            'contact_email': None,
            'contact_phone': None,
            'contact_address': None,
            'support_hours': None,
            'whatsapp_number': None,
            'whatsapp_label': None,
            'payment_cod_enabled': True,
            'payment_card_enabled': False,
            'payment_bank_transfer_enabled': False,
            'payment_cod_label': 'Cash on Delivery',
            'payment_card_label': 'Card Payment',
            'payment_bank_transfer_label': 'Bank Transfer',
            'payment_checkout_notice': None,
            'payment_methods': [
                {
                    'code': 'cod',
                    'label': 'Cash on Delivery',
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
        'contact_address': settings.contact_address,
        'support_hours': settings.support_hours,
        'whatsapp_number': settings.whatsapp_number,
        'whatsapp_label': settings.whatsapp_label,
        'payment_cod_enabled': bool(settings.payment_cod_enabled),
        'payment_card_enabled': bool(settings.payment_card_enabled),
        'payment_bank_transfer_enabled': bool(settings.payment_bank_transfer_enabled),
        'payment_cod_label': settings.payment_cod_label or 'Cash on Delivery',
        'payment_card_label': settings.payment_card_label or 'Card Payment',
        'payment_bank_transfer_label': settings.payment_bank_transfer_label or 'Bank Transfer',
        'payment_checkout_notice': settings.payment_checkout_notice,
        'payment_methods': _serialize_payment_methods(settings),
        'facebook_url': settings.facebook_url,
        'instagram_url': settings.instagram_url,
        'twitter_url': settings.twitter_url,
        'tiktok_url': settings.tiktok_url,
        'snapchat_url': settings.snapchat_url,
        'youtube_url': settings.youtube_url,
    }


def _serialize_offer(offer: Offer):
    return {
        'id': offer.id,
        'title': offer.title,
        'subtitle': offer.subtitle,
        'description': offer.description,
        'banner_url': offer.banner_url,
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


def _serialize_payment_methods(settings: SupportSetting) -> list[dict]:
    return [
        {
            'code': 'cod',
            'label': settings.payment_cod_label or 'Cash on Delivery',
            'enabled': bool(settings.payment_cod_enabled),
        },
        {
            'code': 'card',
            'label': settings.payment_card_label or 'Card Payment',
            'enabled': bool(settings.payment_card_enabled),
        },
        {
            'code': 'bank_transfer',
            'label': settings.payment_bank_transfer_label or 'Bank Transfer',
            'enabled': bool(settings.payment_bank_transfer_enabled),
        },
    ]
