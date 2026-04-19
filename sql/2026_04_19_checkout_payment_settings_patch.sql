-- Checkout payment settings patch
-- Adds admin-configurable payment method availability and checkout notice text.

begin;

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
);

alter table if exists support_settings
  add column if not exists payment_cod_enabled boolean not null default true,
  add column if not exists payment_card_enabled boolean not null default false,
  add column if not exists payment_bank_transfer_enabled boolean not null default false,
  add column if not exists payment_cod_label varchar(120),
  add column if not exists payment_card_label varchar(120),
  add column if not exists payment_bank_transfer_label varchar(120),
  add column if not exists payment_checkout_notice text;

update support_settings
set payment_cod_label = coalesce(nullif(payment_cod_label, ''), 'Cash on Delivery'),
    payment_card_label = coalesce(nullif(payment_card_label, ''), 'Card Payment'),
    payment_bank_transfer_label = coalesce(nullif(payment_bank_transfer_label, ''), 'Bank Transfer')
where true;

insert into support_settings (
  id,
  contact_email,
  contact_phone,
  whatsapp_number,
  whatsapp_label,
  payment_cod_enabled,
  payment_card_enabled,
  payment_bank_transfer_enabled,
  payment_cod_label,
  payment_card_label,
  payment_bank_transfer_label
)
select
  1,
  'support@rokonalshiuokh.com',
  '+966500000000',
  '+966500000000',
  'Chat with Support',
  true,
  false,
  false,
  'Cash on Delivery',
  'Card Payment',
  'Bank Transfer'
where not exists (select 1 from support_settings where id = 1);

commit;
