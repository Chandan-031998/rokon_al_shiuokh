from datetime import datetime

from extensions import db


class SupportSetting(db.Model):
    __tablename__ = 'support_settings'

    id = db.Column(db.BigInteger, primary_key=True)
    contact_email = db.Column(db.String(180))
    contact_phone = db.Column(db.String(40))
    contact_address = db.Column(db.Text)
    support_hours = db.Column(db.String(180))
    whatsapp_number = db.Column(db.String(40))
    whatsapp_label = db.Column(db.String(120))
    payment_cod_enabled = db.Column(db.Boolean, default=True)
    payment_card_enabled = db.Column(db.Boolean, default=False)
    payment_bank_transfer_enabled = db.Column(db.Boolean, default=False)
    payment_cod_label = db.Column(db.String(120))
    payment_card_label = db.Column(db.String(120))
    payment_bank_transfer_label = db.Column(db.String(120))
    payment_checkout_notice = db.Column(db.Text)
    facebook_url = db.Column(db.Text)
    instagram_url = db.Column(db.Text)
    twitter_url = db.Column(db.Text)
    tiktok_url = db.Column(db.Text)
    snapchat_url = db.Column(db.Text)
    youtube_url = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
