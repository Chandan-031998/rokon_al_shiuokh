from __future__ import annotations

from copy import deepcopy
import json

from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from extensions import db
from services.db_compat import clear_table_columns_cache


_CMS_PAGE_SEED: list[dict] = [
    {
        "slug": "privacy-policy",
        "title": "Privacy Policy",
        "section": "policy",
        "excerpt": "How customer data, orders, and account information are handled.",
        "body": (
            "We collect only the information needed to fulfill orders, support "
            "customer accounts, and improve service quality. Contact details, "
            "delivery addresses, and order history are stored securely and are "
            "used only for order processing, support, and operational reporting. "
            "We do not sell customer data to third parties."
        ),
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "return-refund-policy",
        "title": "Return / Refund Policy",
        "section": "policy",
        "excerpt": "Guidance for product issues, returns, and approved refunds.",
        "body": (
            "Customers should report damaged, incorrect, or missing items as "
            "soon as possible after delivery or pickup. Refunds and replacements "
            "are reviewed based on product condition, order status, and branch "
            "fulfillment records. Perishable products may require same-day "
            "reporting for approval."
        ),
        "sort_order": 2,
        "is_active": True,
    },
    {
        "slug": "delivery-policy",
        "title": "Delivery Policy",
        "section": "policy",
        "excerpt": "Branch coverage, delivery timing, and pickup guidance.",
        "body": (
            "Delivery availability depends on the selected branch, live order "
            "volume, and coverage area. Customers can review branch-specific "
            "delivery and pickup availability during checkout. Estimated timing "
            "may vary during peak periods, holidays, or weather disruptions."
        ),
        "sort_order": 3,
        "is_active": True,
    },
    {
        "slug": "terms-and-conditions",
        "title": "Terms & Conditions",
        "section": "policy",
        "excerpt": "Terms for catalog browsing, ordering, payment, and fulfillment.",
        "body": (
            "By using the storefront, customers agree to the current product "
            "pricing, stock availability, fulfillment rules, and payment "
            "conditions published by the business. Orders may be updated or "
            "cancelled when stock, branch readiness, or delivery coverage "
            "changes after placement."
        ),
        "sort_order": 4,
        "is_active": True,
    },
    {
        "slug": "about-us",
        "title": "About Us",
        "section": "about_us",
        "excerpt": "The story and identity behind Rokon Al Shioukh.",
        "body": (
            "Rokon Al Shioukh presents a curated Arabic collection built around "
            "premium coffee, spices, incense, oils, dates, nuts, and heritage-led "
            "giftable products. The brand blends traditional product categories "
            "with modern ordering, branch service, and operational control."
        ),
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "contact-us",
        "title": "Contact Us",
        "section": "contact_us",
        "excerpt": "Ways customers can reach support, branches, and order assistance.",
        "body": (
            "Customers can reach the team through the published phone number, "
            "WhatsApp contact, branch support details, and social channels. "
            "Use the support center for order questions, delivery clarification, "
            "and branch pickup coordination."
        ),
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "homepage-hero-main",
        "title": "Homepage Hero Main",
        "section": "hero_banner",
        "excerpt": "Luxury Arabic collection for coffee, gifting, and daily rituals.",
        "body": (
            "Discover a premium selection shaped around Arabic hospitality, "
            "signature blends, and branch-backed fulfillment."
        ),
        "cta_label": "Browse Collection",
        "metadata_json": {
            "title_ar": "الواجهة الرئيسية للمجموعة الفاخرة",
            "excerpt_ar": "مجموعة عربية فاخرة للقهوة والهدايا والطقوس اليومية.",
            "body_ar": "اكتشف تشكيلة مميزة مستوحاة من الضيافة العربية مع توفر الفروع وخدمة الطلب الحديثة.",
            "cta_label_ar": "تصفح المجموعة",
            "eyebrow": "Signature Collection",
            "eyebrow_ar": "تشكيلة مميزة",
            "secondary_label": "Change Branch",
            "secondary_label_ar": "غيّر الفرع",
            "metric": "Majlis Ready",
            "metric_ar": "جاهز للمجلس",
        },
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "homepage-collection-highlight",
        "title": "Collection Highlight",
        "section": "home_section_banner",
        "excerpt": "Spotlight an important collection or featured release.",
        "body": (
            "Use this section to highlight a seasonal range, signature category, "
            "or premium limited collection."
        ),
        "cta_label": "Explore Highlight",
        "metadata_json": {
            "title_ar": "إبراز مجموعة مميزة",
            "excerpt_ar": "سلط الضوء على مجموعة موسمية أو إصدار مختار.",
            "body_ar": "استخدم هذا القسم لإبراز مجموعة موسمية أو فئة مميزة أو إصدار محدود فاخر.",
            "cta_label_ar": "اكتشف الإبراز",
        },
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "home-marketing-card-delivery",
        "title": "Delivery Promise",
        "section": "marketing_card",
        "excerpt": "Branch-led delivery confidence with pickup flexibility.",
        "body": (
            "Customers can order with clear branch availability, pickup options, "
            "and support-aware delivery guidance."
        ),
        "metadata_json": {
            "title_ar": "وعد التوصيل",
            "excerpt_ar": "ثقة في التوصيل بقيادة الفروع مع مرونة الاستلام.",
            "body_ar": "يمكن للعملاء الطلب مع وضوح توفر الفروع وخيارات الاستلام وإرشادات التوصيل المدارة من الدعم.",
        },
        "sort_order": 1,
        "is_active": True,
    },
    {
        "slug": "delivery-block-main",
        "title": "Delivery Information",
        "section": "delivery_information",
        "excerpt": "View branch coverage, pickup availability, and support details.",
        "body": (
            "Delivery coverage, branch readiness, and customer support details "
            "are managed centrally so customers can see the latest service "
            "information before placing an order."
        ),
        "metadata_json": {
            "title_ar": "معلومات التوصيل",
            "excerpt_ar": "اطلع على نطاق الفروع وخيارات الاستلام وتفاصيل الدعم.",
            "body_ar": "تتم إدارة نطاق التوصيل وجهوزية الفروع وتفاصيل دعم العملاء مركزياً حتى يرى العميل أحدث المعلومات قبل الطلب.",
        },
        "sort_order": 1,
        "is_active": True,
    },
]

_FAQ_SEED: list[dict] = [
    {
        "question": "How long does delivery take?",
        "answer": (
            "Delivery timing depends on the selected branch, your delivery area, "
            "and current order volume. The checkout flow and support center show "
            "the latest branch-backed service information."
        ),
        "sort_order": 1,
        "is_active": True,
    },
    {
        "question": "Can I collect my order from a branch?",
        "answer": (
            "Yes. Pickup availability is managed per branch. If pickup is enabled "
            "for the selected branch, customers can choose it during checkout."
        ),
        "sort_order": 2,
        "is_active": True,
    },
]

_SUPPORT_SETTINGS_SEED: dict = {
    "id": 1,
    "contact_email": "support@rokonalshiuokh.com",
    "contact_phone": "+966500000000",
    "contact_address": "Mahayil Aseer & Abha branch support coverage",
    "contact_address_ar": "تغطية دعم فروع محايل عسير وأبها",
    "support_hours": "Daily support hours managed by admin",
    "support_hours_ar": "ساعات الدعم اليومية تتم إدارتها من لوحة التحكم",
    "whatsapp_number": "+966500000000",
    "whatsapp_label": "Chat with Support",
    "whatsapp_label_ar": "تواصل عبر واتساب",
    "payment_cod_enabled": True,
    "payment_card_enabled": False,
    "payment_bank_transfer_enabled": False,
    "payment_cod_label": "Cash on Delivery",
    "payment_card_label": "Card Payment",
    "payment_bank_transfer_label": "Bank Transfer",
    "payment_checkout_notice": None,
    "facebook_url": None,
    "instagram_url": None,
    "twitter_url": None,
    "tiktok_url": None,
    "snapchat_url": None,
    "youtube_url": None,
}


def default_cms_pages() -> list[dict]:
    return deepcopy(_CMS_PAGE_SEED)


def default_cms_page_by_slug(slug: str) -> dict | None:
    normalized = (slug or "").strip().lower()
    for index, page in enumerate(_CMS_PAGE_SEED, start=1):
        if page["slug"] == normalized:
            payload = deepcopy(page)
            payload["id"] = index
            payload["metadata_json"] = {}
            payload["image_url"] = None
            payload["cta_label"] = None
            payload["cta_url"] = None
            payload["created_at"] = None
            payload["updated_at"] = None
            return payload
    return None


def default_faqs() -> list[dict]:
    return [
        {
            "id": index,
            "created_at": None,
            "updated_at": None,
            **deepcopy(faq),
        }
        for index, faq in enumerate(_FAQ_SEED, start=1)
    ]


def default_support_settings() -> dict:
    payload = deepcopy(_SUPPORT_SETTINGS_SEED)
    payload["payment_methods"] = [
        {
            "code": "cod",
            "label": payload["payment_cod_label"],
            "enabled": bool(payload["payment_cod_enabled"]),
        },
        {
            "code": "card",
            "label": payload["payment_card_label"],
            "enabled": bool(payload["payment_card_enabled"]),
        },
        {
            "code": "bank_transfer",
            "label": payload["payment_bank_transfer_label"],
            "enabled": bool(payload["payment_bank_transfer_enabled"]),
        },
    ]
    return payload


def ensure_content_management_data():
    try:
        _ensure_content_schema()
        clear_table_columns_cache()
        changed = False
        changed |= _seed_cms_pages()
        changed |= _seed_faqs()
        changed |= _seed_support_settings()
        if changed:
            db.session.commit()
    except SQLAlchemyError:
        db.session.rollback()


def _ensure_content_schema():
    statements = [
        """
        create table if not exists cms_pages (
          id bigserial primary key,
          slug varchar(160) not null unique,
          title varchar(180) not null,
          section varchar(60) not null,
          excerpt varchar(280),
          body text,
          image_url text,
          cta_label varchar(80),
          cta_url text,
          metadata_json jsonb not null default '{}'::jsonb,
          sort_order integer not null default 0,
          is_active boolean not null default true,
          created_at timestamptz not null default now(),
          updated_at timestamptz not null default now()
        )
        """,
        """
        alter table if exists cms_pages
          add column if not exists excerpt varchar(280),
          add column if not exists body text,
          add column if not exists image_url text,
          add column if not exists cta_label varchar(80),
          add column if not exists cta_url text,
          add column if not exists metadata_json jsonb not null default '{}'::jsonb,
          add column if not exists sort_order integer not null default 0,
          add column if not exists is_active boolean not null default true,
          add column if not exists created_at timestamptz not null default now(),
          add column if not exists updated_at timestamptz not null default now()
        """,
        """
        create table if not exists faqs (
          id bigserial primary key,
          question varchar(240) not null,
          answer text not null,
          sort_order integer not null default 0,
          is_active boolean not null default true,
          created_at timestamptz not null default now(),
          updated_at timestamptz not null default now()
        )
        """,
        """
        alter table if exists faqs
          add column if not exists sort_order integer not null default 0,
          add column if not exists is_active boolean not null default true,
          add column if not exists created_at timestamptz not null default now(),
          add column if not exists updated_at timestamptz not null default now()
        """,
        """
        create table if not exists support_settings (
          id bigserial primary key,
          contact_email varchar(180),
          contact_phone varchar(40),
          contact_address text,
          support_hours varchar(180),
          whatsapp_number varchar(40),
          whatsapp_label varchar(120),
          facebook_url text,
          instagram_url text,
          twitter_url text,
          tiktok_url text,
          snapchat_url text,
          youtube_url text,
          created_at timestamptz not null default now(),
          updated_at timestamptz not null default now()
        )
        """,
        """
        alter table if exists support_settings
          add column if not exists contact_address text,
          add column if not exists contact_address_ar text,
          add column if not exists support_hours varchar(180),
          add column if not exists support_hours_ar varchar(180),
          add column if not exists whatsapp_label_ar varchar(120),
          add column if not exists payment_cod_enabled boolean not null default true,
          add column if not exists payment_card_enabled boolean not null default false,
          add column if not exists payment_bank_transfer_enabled boolean not null default false,
          add column if not exists payment_cod_label varchar(120),
          add column if not exists payment_card_label varchar(120),
          add column if not exists payment_bank_transfer_label varchar(120),
          add column if not exists payment_checkout_notice text,
          add column if not exists facebook_url text,
          add column if not exists instagram_url text,
          add column if not exists twitter_url text,
          add column if not exists tiktok_url text,
          add column if not exists snapchat_url text,
          add column if not exists youtube_url text,
          add column if not exists created_at timestamptz not null default now(),
          add column if not exists updated_at timestamptz not null default now()
        """,
        "create index if not exists idx_cms_pages_section on cms_pages(section, sort_order)",
        "create index if not exists idx_faqs_sort_order on faqs(sort_order)",
    ]

    for statement in statements:
        db.session.execute(text(statement))


def _seed_cms_pages() -> bool:
    changed = False
    for page in _CMS_PAGE_SEED:
        exists = db.session.execute(
            text("select id from cms_pages where slug = :slug limit 1"),
            {"slug": page["slug"]},
        ).scalar()
        if exists:
            continue

        db.session.execute(
            text(
                """
                insert into cms_pages (
                    slug,
                    title,
                    section,
                    excerpt,
                    body,
                    image_url,
                    cta_label,
                    cta_url,
                    sort_order,
                    is_active,
                    metadata_json
                )
                values (
                    :slug,
                    :title,
                    :section,
                    :excerpt,
                    :body,
                    :image_url,
                    :cta_label,
                    :cta_url,
                    :sort_order,
                    :is_active,
                    cast(:metadata_json as jsonb)
                )
                """
            ),
            {
                **page,
                "image_url": page.get("image_url"),
                "cta_label": page.get("cta_label"),
                "cta_url": page.get("cta_url"),
                "metadata_json": json.dumps(page.get("metadata_json") or {}),
            },
        )
        changed = True
    return changed


def _seed_faqs() -> bool:
    changed = False
    for faq in _FAQ_SEED:
        exists = db.session.execute(
            text("select id from faqs where question = :question limit 1"),
            {"question": faq["question"]},
        ).scalar()
        if exists:
            continue

        db.session.execute(
            text(
                """
                insert into faqs (question, answer, sort_order, is_active)
                values (:question, :answer, :sort_order, :is_active)
                """
            ),
            faq,
        )
        changed = True
    return changed


def _seed_support_settings() -> bool:
    exists = db.session.execute(
        text("select id from support_settings where id = 1 limit 1")
    ).scalar()
    if exists:
        db.session.execute(
            text(
                """
                update support_settings
                set payment_cod_label = coalesce(nullif(payment_cod_label, ''), :payment_cod_label),
                    payment_card_label = coalesce(nullif(payment_card_label, ''), :payment_card_label),
                    payment_bank_transfer_label = coalesce(nullif(payment_bank_transfer_label, ''), :payment_bank_transfer_label)
                where id = 1
                """
            ),
            {
                "payment_cod_label": _SUPPORT_SETTINGS_SEED["payment_cod_label"],
                "payment_card_label": _SUPPORT_SETTINGS_SEED["payment_card_label"],
                "payment_bank_transfer_label": _SUPPORT_SETTINGS_SEED["payment_bank_transfer_label"],
            },
        )
        return False

    db.session.execute(
        text(
            """
                insert into support_settings (
                    id,
                    contact_email,
                    contact_phone,
                    contact_address,
                    contact_address_ar,
                    support_hours,
                    support_hours_ar,
                    whatsapp_number,
                    whatsapp_label,
                    whatsapp_label_ar,
                    payment_cod_enabled,
                payment_card_enabled,
                payment_bank_transfer_enabled,
                payment_cod_label,
                payment_card_label,
                payment_bank_transfer_label,
                payment_checkout_notice,
                facebook_url,
                instagram_url,
                twitter_url,
                tiktok_url,
                snapchat_url,
                youtube_url
            )
            values (
                :id,
                :contact_email,
                    :contact_phone,
                    :contact_address,
                    :contact_address_ar,
                    :support_hours,
                    :support_hours_ar,
                    :whatsapp_number,
                    :whatsapp_label,
                    :whatsapp_label_ar,
                    :payment_cod_enabled,
                :payment_card_enabled,
                :payment_bank_transfer_enabled,
                :payment_cod_label,
                :payment_card_label,
                :payment_bank_transfer_label,
                :payment_checkout_notice,
                :facebook_url,
                :instagram_url,
                :twitter_url,
                :tiktok_url,
                :snapchat_url,
                :youtube_url
            )
            """
        ),
        _SUPPORT_SETTINGS_SEED,
    )
    return True
