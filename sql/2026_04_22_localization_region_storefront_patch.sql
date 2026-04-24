alter table categories
  add column if not exists name_en varchar(120);

update categories
set name_en = coalesce(nullif(name_en, ''), name)
where coalesce(name_en, '') = '';

alter table products
  add column if not exists name_en varchar(200),
  add column if not exists short_description_en varchar(280),
  add column if not exists short_description_ar varchar(280),
  add column if not exists full_description_en text,
  add column if not exists full_description_ar text;

update products
set
  name_en = coalesce(nullif(name_en, ''), name),
  short_description_en = coalesce(nullif(short_description_en, ''), short_description),
  full_description_en = coalesce(nullif(full_description_en, ''), full_description)
where
  coalesce(name_en, '') = ''
  or coalesce(short_description_en, '') = ''
  or coalesce(full_description_en, '') = '';

alter table cms_pages
  add column if not exists title_en varchar(180),
  add column if not exists title_ar varchar(180),
  add column if not exists excerpt_en varchar(280),
  add column if not exists excerpt_ar varchar(280),
  add column if not exists body_en text,
  add column if not exists body_ar text,
  add column if not exists region_code varchar(2);

update cms_pages
set
  title_en = coalesce(nullif(title_en, ''), title),
  excerpt_en = coalesce(nullif(excerpt_en, ''), excerpt),
  body_en = coalesce(nullif(body_en, ''), body)
where
  coalesce(title_en, '') = ''
  or coalesce(excerpt_en, '') = ''
  or coalesce(body_en, '') = '';

alter table offers
  add column if not exists title_en varchar(150),
  add column if not exists title_ar varchar(150),
  add column if not exists subtitle varchar(180),
  add column if not exists subtitle_en varchar(180),
  add column if not exists subtitle_ar varchar(180),
  add column if not exists description_en text,
  add column if not exists description_ar text,
  add column if not exists region_code varchar(2),
  add column if not exists currency_code varchar(3),
  add column if not exists product_id bigint references products(id) on delete set null,
  add column if not exists category_id bigint references categories(id) on delete set null,
  add column if not exists branch_id bigint references branches(id) on delete set null;

update offers
set
  title_en = coalesce(nullif(title_en, ''), title),
  subtitle_en = coalesce(nullif(subtitle_en, ''), subtitle),
  description_en = coalesce(nullif(description_en, ''), description)
where
  coalesce(title_en, '') = ''
  or coalesce(subtitle_en, '') = ''
  or coalesce(description_en, '') = '';

alter table branches
  add column if not exists region_code varchar(2),
  add column if not exists default_currency_code varchar(3),
  add column if not exists pickup_available boolean not null default true,
  add column if not exists delivery_available boolean not null default true,
  add column if not exists delivery_coverage text;

update branches
set
  region_code = coalesce(nullif(region_code, ''), 'sa'),
  default_currency_code = coalesce(nullif(default_currency_code, ''), 'SAR')
where
  coalesce(region_code, '') = ''
  or coalesce(default_currency_code, '') = '';

create table if not exists product_region_prices (
  id bigserial primary key,
  product_id bigint not null references products(id) on delete cascade,
  region_code varchar(2) not null,
  currency_code varchar(3) not null,
  price numeric(10,2) not null check (price >= 0),
  sale_price numeric(10,2) check (sale_price is null or (sale_price >= 0 and sale_price <= price)),
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (product_id, region_code)
);

insert into product_region_prices (
  product_id,
  region_code,
  currency_code,
  price,
  sale_price,
  is_visible
)
select
  p.id,
  'sa',
  'SAR',
  p.price,
  p.sale_price,
  true
from products p
where not exists (
  select 1
  from product_region_prices prp
  where prp.product_id = p.id
    and prp.region_code = 'sa'
);

create table if not exists branch_region_settings (
  id bigserial primary key,
  branch_id bigint not null references branches(id) on delete cascade,
  region_code varchar(2) not null,
  currency_code varchar(3) not null,
  is_visible boolean not null default true,
  pickup_available boolean not null default true,
  delivery_available boolean not null default true,
  delivery_coverage text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, region_code)
);

insert into branch_region_settings (
  branch_id,
  region_code,
  currency_code,
  is_visible,
  pickup_available,
  delivery_available,
  delivery_coverage
)
select
  b.id,
  'sa',
  coalesce(nullif(b.default_currency_code, ''), 'SAR'),
  true,
  b.pickup_available,
  b.delivery_available,
  b.delivery_coverage
from branches b
where not exists (
  select 1
  from branch_region_settings brs
  where brs.branch_id = b.id
    and brs.region_code = 'sa'
);
