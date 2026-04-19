-- Rokon Al Shiuokh PostgreSQL schema for Supabase
-- Safe to run on a fresh project. Review before production use.

create extension if not exists pgcrypto;

create table if not exists users (
  id bigserial primary key,
  full_name varchar(120) not null,
  email varchar(150) not null unique,
  phone varchar(30) unique,
  password_hash text not null,
  role varchar(20) not null default 'customer',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists branches (
  id bigserial primary key,
  name varchar(120) not null,
  city varchar(120),
  address text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  phone varchar(30),
  map_link text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists categories (
  id bigserial primary key,
  name varchar(120) not null,
  name_ar varchar(120),
  image_url text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists products (
  id bigserial primary key,
  category_id bigint not null references categories(id) on delete restrict,
  branch_id bigint references branches(id) on delete set null,
  name varchar(200) not null,
  name_ar varchar(200),
  sku varchar(80) unique,
  short_description varchar(280),
  description text,
  full_description text,
  price numeric(10,2) not null check (price >= 0),
  sale_price numeric(10,2) check (sale_price is null or (sale_price >= 0 and sale_price <= price)),
  stock_qty integer not null default 0 check (stock_qty >= 0),
  tags text,
  search_keywords text,
  search_synonyms text,
  image_url text,
  is_featured boolean not null default false,
  is_hidden_from_search boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists addresses (
  id bigserial primary key,
  user_id bigint references users(id) on delete cascade,
  guest_session_id varchar(120),
  label varchar(60) default 'Home',
  city varchar(100),
  neighborhood varchar(100),
  address_line text not null,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists cart_items (
  id bigserial primary key,
  user_id bigint references users(id) on delete cascade,
  guest_session_id varchar(120),
  product_id bigint not null references products(id) on delete cascade,
  branch_id bigint references branches(id) on delete set null,
  quantity integer not null default 1 check (quantity > 0),
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id bigserial primary key,
  user_id bigint references users(id) on delete cascade,
  guest_session_id varchar(120),
  branch_id bigint references branches(id) on delete set null,
  address_id bigint references addresses(id) on delete set null,
  order_number varchar(40) not null unique,
  order_type varchar(20) not null default 'delivery',
  payment_method varchar(30) not null default 'cod',
  payment_status varchar(30) not null default 'pending',
  order_status varchar(30) not null default 'placed',
  subtotal numeric(10,2) not null default 0,
  delivery_fee numeric(10,2) not null default 0,
  discount_amount numeric(10,2) not null default 0,
  total_amount numeric(10,2) not null default 0,
  delivery_slot varchar(80),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists order_items (
  id bigserial primary key,
  order_id bigint not null references orders(id) on delete cascade,
  product_id bigint references products(id) on delete set null,
  product_name varchar(200) not null,
  price numeric(10,2) not null default 0,
  quantity integer not null default 1 check (quantity > 0),
  line_total numeric(10,2) not null default 0
);

create table if not exists notifications (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  title varchar(150) not null,
  body text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists offers (
  id bigserial primary key,
  title varchar(150) not null,
  description text,
  banner_url text,
  discount_type varchar(20),
  discount_value numeric(10,2) default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

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
);

create table if not exists faqs (
  id bigserial primary key,
  question varchar(240) not null,
  answer text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists support_settings (
  id bigserial primary key,
  contact_email varchar(180),
  contact_phone varchar(40),
  contact_address text,
  support_hours varchar(180),
  whatsapp_number varchar(40),
  whatsapp_label varchar(120),
  payment_cod_enabled boolean not null default true,
  payment_card_enabled boolean not null default false,
  payment_bank_transfer_enabled boolean not null default false,
  payment_cod_label varchar(120),
  payment_card_label varchar(120),
  payment_bank_transfer_label varchar(120),
  payment_checkout_notice text,
  facebook_url text,
  instagram_url text,
  twitter_url text,
  tiktok_url text,
  snapchat_url text,
  youtube_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists search_terms (
  id bigserial primary key,
  term varchar(160) not null unique,
  term_type varchar(30) not null default 'popular'
    check (term_type in ('popular', 'featured')),
  synonyms text,
  linked_category_id bigint references categories(id) on delete set null,
  linked_product_id bigint references products(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists filter_groups (
  id bigserial primary key,
  name varchar(140) not null,
  slug varchar(160) not null unique,
  filter_type varchar(40) not null default 'multi_select'
    check (filter_type in ('multi_select', 'single_select', 'swatch', 'bucket')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists filter_values (
  id bigserial primary key,
  group_id bigint not null references filter_groups(id) on delete cascade,
  value varchar(140) not null,
  value_ar varchar(140),
  slug varchar(160) not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists category_filter_group_map (
  category_id bigint not null references categories(id) on delete cascade,
  filter_group_id bigint not null references filter_groups(id) on delete cascade,
  primary key (category_id, filter_group_id)
);

create table if not exists product_filter_map (
  product_id bigint not null references products(id) on delete cascade,
  filter_value_id bigint not null references filter_values(id) on delete cascade,
  primary key (product_id, filter_value_id)
);

create table if not exists reviews (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  product_id bigint not null references products(id) on delete cascade,
  order_id bigint references orders(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  title varchar(180),
  body text,
  moderation_status varchar(30) not null default 'pending'
    check (moderation_status in ('pending', 'approved', 'rejected')),
  moderation_notes text,
  is_verified_purchase boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists wishlist_items (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  product_id bigint not null references products(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

alter table if exists cart_items drop constraint if exists cart_items_user_id_product_id_key;
alter table if exists cart_items add column if not exists guest_session_id varchar(120);
alter table if exists cart_items add column if not exists branch_id bigint references branches(id) on delete set null;
alter table if exists cart_items alter column user_id drop not null;
alter table if exists addresses add column if not exists guest_session_id varchar(120);
alter table if exists addresses alter column user_id drop not null;
alter table if exists orders add column if not exists guest_session_id varchar(120);
alter table if exists orders alter column user_id drop not null;

create index if not exists idx_products_category on products(category_id);
create index if not exists idx_products_branch on products(branch_id);
create index if not exists idx_orders_user on orders(user_id);
create index if not exists idx_orders_guest on orders(guest_session_id);
create index if not exists idx_order_items_order on order_items(order_id);
create index if not exists idx_cart_items_user on cart_items(user_id);
create index if not exists idx_cart_items_guest on cart_items(guest_session_id);
create index if not exists idx_cart_items_branch on cart_items(branch_id);
create index if not exists idx_addresses_guest on addresses(guest_session_id);
create index if not exists idx_cms_pages_section on cms_pages(section, sort_order);
create index if not exists idx_faqs_sort_order on faqs(sort_order);
create index if not exists idx_reviews_product_status on reviews(product_id, moderation_status, created_at desc);
create index if not exists idx_reviews_user on reviews(user_id, created_at desc);
create index if not exists idx_reviews_rating on reviews(rating);
create index if not exists idx_wishlist_user_created on wishlist_items(user_id, created_at desc);
create index if not exists idx_products_hidden_search on products(is_hidden_from_search, is_active);
create index if not exists idx_products_search_keywords on products using gin (to_tsvector('simple', coalesce(search_keywords, '')));
create index if not exists idx_products_search_synonyms on products using gin (to_tsvector('simple', coalesce(search_synonyms, '')));
create index if not exists idx_search_terms_type_sort on search_terms(term_type, sort_order, is_active);
create index if not exists idx_filter_groups_sort on filter_groups(sort_order, is_active);
create index if not exists idx_filter_values_group_sort on filter_values(group_id, sort_order, is_active);
create index if not exists idx_product_filter_map_value on product_filter_map(filter_value_id, product_id);

create unique index if not exists uq_cart_items_user_product_branch
  on cart_items(user_id, product_id, coalesce(branch_id, -1))
  where user_id is not null;

create unique index if not exists uq_cart_items_guest_product_branch
  on cart_items(guest_session_id, product_id, coalesce(branch_id, -1))
  where guest_session_id is not null;

-- Seed branches from project brief
insert into branches (name, city, address, phone)
select 'Mahayil Aseer (Main Branch)', 'Mahayil Aseer', 'Main branch address', '+966500000001'
where not exists (select 1 from branches where name = 'Mahayil Aseer (Main Branch)');

insert into branches (name, city, address, phone)
select 'Abha Branch', 'Abha', 'Abha branch address', '+966500000002'
where not exists (select 1 from branches where name = 'Abha Branch');

-- Seed categories from project brief
insert into categories (name, name_ar, sort_order)
select * from (
  values
    ('Coffee', 'القهوة', 1),
    ('Spices', 'البهارات', 2),
    ('Herbs & Attar', 'الأعشاب والعطور', 3),
    ('Incense', 'البخور', 4),
    ('Nuts', 'المكسرات', 5),
    ('Dates', 'التمور', 6),
    ('Oils', 'الزيوت', 7)
) as v(name, name_ar, sort_order)
where not exists (
  select 1 from categories c where c.name = v.name
);

-- Optional demo products
insert into products (category_id, branch_id, name, name_ar, sku, description, price, stock_qty, is_featured)
select c.id, b.id, 'Premium Arabic Coffee', 'قهوة عربية فاخرة', 'COF-001', 'Starter demo product', 28.00, 100, true
from categories c cross join branches b
where c.name = 'Coffee' and b.name = 'Mahayil Aseer (Main Branch)'
  and not exists (select 1 from products where sku = 'COF-001');

insert into products (category_id, branch_id, name, name_ar, sku, description, price, stock_qty, is_featured)
select c.id, b.id, 'Luxury Saffron Mix', 'خلطة زعفران فاخرة', 'SPI-001', 'Starter demo product', 39.00, 80, true
from categories c cross join branches b
where c.name = 'Spices' and b.name = 'Abha Branch'
  and not exists (select 1 from products where sku = 'SPI-001');

insert into search_terms (term, term_type, synonyms, sort_order, is_active)
select 'arabic coffee', 'popular', 'gahwa,qahwa,coffee', 1, true
where not exists (select 1 from search_terms where term = 'arabic coffee');

insert into search_terms (term, term_type, synonyms, sort_order, is_active)
select 'saffron', 'featured', 'zafaran,spice', 2, true
where not exists (select 1 from search_terms where term = 'saffron');

insert into search_terms (term, term_type, synonyms, sort_order, is_active)
select 'incense', 'popular', 'bukhoor,bakhour', 3, true
where not exists (select 1 from search_terms where term = 'incense');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'privacy-policy', 'Privacy Policy', 'policy', 'Privacy and personal data handling overview.', 'Privacy policy content can be managed here.', 1, true
where not exists (select 1 from cms_pages where slug = 'privacy-policy');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'return-refund-policy', 'Return / Refund Policy', 'policy', 'Return and refund conditions.', 'Return and refund policy content can be managed here.', 2, true
where not exists (select 1 from cms_pages where slug = 'return-refund-policy');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'delivery-policy', 'Delivery Policy', 'policy', 'Delivery timing, branch coverage, and availability.', 'Delivery policy content can be managed here.', 3, true
where not exists (select 1 from cms_pages where slug = 'delivery-policy');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'terms-and-conditions', 'Terms & Conditions', 'policy', 'Commercial terms and platform rules.', 'Terms and conditions content can be managed here.', 4, true
where not exists (select 1 from cms_pages where slug = 'terms-and-conditions');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'about-us', 'About Us', 'about_us', 'Brand story and company background.', 'About Us content can be managed here.', 1, true
where not exists (select 1 from cms_pages where slug = 'about-us');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'contact-us', 'Contact Us', 'contact_us', 'Ways customers can reach your team.', 'Contact Us content can be managed here.', 1, true
where not exists (select 1 from cms_pages where slug = 'contact-us');

insert into cms_pages (slug, title, section, excerpt, body, sort_order, is_active)
select 'homepage-hero-main', 'Homepage Hero Main', 'hero_banner', 'Primary homepage hero banner.', 'Primary homepage hero banner content.', 1, true
where not exists (select 1 from cms_pages where slug = 'homepage-hero-main');

insert into support_settings (id, contact_email, contact_phone, whatsapp_number, whatsapp_label)
select 1, 'support@rokonalshiuokh.com', '+966500000000', '+966500000000', 'Chat with Support'
where not exists (select 1 from support_settings where id = 1);
