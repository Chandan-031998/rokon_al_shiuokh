-- Admin catalog management patch
-- Adds richer product metadata and branch location fields.

begin;

alter table if exists products
  add column if not exists short_description varchar(280),
  add column if not exists full_description text,
  add column if not exists sale_price numeric(10,2),
  add column if not exists tags text;

alter table if exists branches
  add column if not exists map_link text;

update products
set short_description = coalesce(short_description, description)
where description is not null and short_description is null;

update products
set full_description = coalesce(full_description, description)
where description is not null and full_description is null;

alter table if exists products
  drop constraint if exists products_sale_price_check;

alter table if exists products
  add constraint products_sale_price_check
  check (sale_price is null or (sale_price >= 0 and sale_price <= price));

create index if not exists idx_products_sale_price on products(sale_price);
create index if not exists idx_products_tags on products using gin (to_tsvector('simple', coalesce(tags, '')));
create index if not exists idx_products_short_description on products using gin (to_tsvector('simple', coalesce(short_description, '')));

commit;
