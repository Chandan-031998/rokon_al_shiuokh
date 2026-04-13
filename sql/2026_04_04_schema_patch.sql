-- Rokon Al Shiuokh non-destructive schema patch
-- Purpose:
-- 1. Align the schema with the current backend behavior
-- 2. Add admin/dashboard-friendly auditing columns
-- 3. Improve indexing and integrity constraints
-- 4. Expand notifications/offers for future use without breaking current data
-- 5. Re-seed branches/categories safely if they are missing

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

alter table if exists users add column if not exists updated_at timestamptz not null default now();
alter table if exists branches add column if not exists updated_at timestamptz not null default now();
alter table if exists categories add column if not exists updated_at timestamptz not null default now();
alter table if exists products add column if not exists updated_at timestamptz not null default now();
alter table if exists addresses add column if not exists updated_at timestamptz not null default now();
alter table if exists cart_items add column if not exists updated_at timestamptz not null default now();
alter table if exists orders add column if not exists updated_at timestamptz not null default now();
alter table if exists order_items add column if not exists updated_at timestamptz not null default now();
alter table if exists notifications add column if not exists updated_at timestamptz not null default now();
alter table if exists offers add column if not exists updated_at timestamptz not null default now();

drop trigger if exists trg_users_set_updated_at on users;
create trigger trg_users_set_updated_at before update on users
for each row execute function public.set_updated_at();

drop trigger if exists trg_branches_set_updated_at on branches;
create trigger trg_branches_set_updated_at before update on branches
for each row execute function public.set_updated_at();

drop trigger if exists trg_categories_set_updated_at on categories;
create trigger trg_categories_set_updated_at before update on categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_products_set_updated_at on products;
create trigger trg_products_set_updated_at before update on products
for each row execute function public.set_updated_at();

drop trigger if exists trg_addresses_set_updated_at on addresses;
create trigger trg_addresses_set_updated_at before update on addresses
for each row execute function public.set_updated_at();

drop trigger if exists trg_cart_items_set_updated_at on cart_items;
create trigger trg_cart_items_set_updated_at before update on cart_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_orders_set_updated_at on orders;
create trigger trg_orders_set_updated_at before update on orders
for each row execute function public.set_updated_at();

drop trigger if exists trg_order_items_set_updated_at on order_items;
create trigger trg_order_items_set_updated_at before update on order_items
for each row execute function public.set_updated_at();

drop trigger if exists trg_notifications_set_updated_at on notifications;
create trigger trg_notifications_set_updated_at before update on notifications
for each row execute function public.set_updated_at();

drop trigger if exists trg_offers_set_updated_at on offers;
create trigger trg_offers_set_updated_at before update on offers
for each row execute function public.set_updated_at();

alter table if exists orders alter column order_status set default 'pending';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_addresses_owner_present'
  ) then
    alter table addresses
      add constraint chk_addresses_owner_present
      check (user_id is not null or guest_session_id is not null);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_cart_items_owner_present'
  ) then
    alter table cart_items
      add constraint chk_cart_items_owner_present
      check (user_id is not null or guest_session_id is not null);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_orders_owner_present'
  ) then
    alter table orders
      add constraint chk_orders_owner_present
      check (user_id is not null or guest_session_id is not null);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_orders_order_type'
  ) then
    alter table orders
      add constraint chk_orders_order_type
      check (order_type in ('delivery', 'pickup'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_orders_payment_status'
  ) then
    alter table orders
      add constraint chk_orders_payment_status
      check (payment_status in ('pending', 'paid', 'failed', 'refunded', 'cancelled'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_orders_order_status'
  ) then
    alter table orders
      add constraint chk_orders_order_status
      check (
        order_status in (
          'pending',
          'confirmed',
          'preparing',
          'out_for_delivery',
          'ready_for_pickup',
          'delivered',
          'cancelled'
        )
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_offers_discount_value'
  ) then
    alter table offers
      add constraint chk_offers_discount_value
      check (discount_value >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_offers_discount_type'
  ) then
    alter table offers
      add constraint chk_offers_discount_type
      check (
        discount_type is null
        or discount_type in ('percentage', 'fixed_amount', 'bundle')
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'chk_offers_valid_window'
  ) then
    alter table offers
      add constraint chk_offers_valid_window
      check (ends_at is null or starts_at is null or ends_at >= starts_at);
  end if;
end $$;

alter table if exists notifications add column if not exists type varchar(50) not null default 'general';
alter table if exists notifications add column if not exists data jsonb not null default '{}'::jsonb;
alter table if exists notifications add column if not exists read_at timestamptz;
alter table if exists notifications add column if not exists order_id bigint references orders(id) on delete cascade;

alter table if exists offers add column if not exists promo_code varchar(60);
alter table if exists offers add column if not exists sort_order integer not null default 0;
alter table if exists offers add column if not exists branch_id bigint references branches(id) on delete set null;
alter table if exists offers add column if not exists category_id bigint references categories(id) on delete set null;
alter table if exists offers add column if not exists product_id bigint references products(id) on delete set null;
alter table if exists offers add column if not exists badge_label varchar(60);
alter table if exists offers add column if not exists cta_label varchar(60);
alter table if exists offers add column if not exists cta_url text;
alter table if exists offers add column if not exists background_color varchar(20);
alter table if exists offers add column if not exists text_color varchar(20);

create index if not exists idx_users_created_at on users(created_at desc);
create index if not exists idx_branches_active_name on branches(is_active, name);
create index if not exists idx_categories_sort_order on categories(sort_order, id);
create index if not exists idx_products_active_category on products(is_active, category_id, id desc);
create index if not exists idx_products_featured_active on products(is_featured, is_active, id desc);
create index if not exists idx_products_sku on products(sku);
create index if not exists idx_addresses_user_default on addresses(user_id, is_default desc, created_at desc);
create index if not exists idx_addresses_guest_default on addresses(guest_session_id, is_default desc, created_at desc);
create index if not exists idx_cart_items_created_at on cart_items(created_at desc);
create index if not exists idx_orders_status_created_at on orders(order_status, created_at desc);
create index if not exists idx_orders_branch_created_at on orders(branch_id, created_at desc);
create index if not exists idx_order_items_product on order_items(product_id);
create index if not exists idx_notifications_user_read on notifications(user_id, is_read, created_at desc);
create index if not exists idx_notifications_order on notifications(order_id);
create index if not exists idx_offers_active_window on offers(is_active, starts_at, ends_at);
create index if not exists idx_offers_sort_order on offers(sort_order, created_at desc);
create index if not exists idx_offers_branch on offers(branch_id);
create index if not exists idx_offers_category on offers(category_id);
create index if not exists idx_offers_product on offers(product_id);

create unique index if not exists uq_branches_name on branches(name);
create unique index if not exists uq_categories_name on categories(name);
create unique index if not exists uq_offers_promo_code
  on offers(promo_code)
  where promo_code is not null and length(trim(promo_code)) > 0;

update branches
set
  city = 'Mahayil Aseer',
  address = coalesce(address, 'Main branch address'),
  phone = coalesce(phone, '+966500000001'),
  is_active = true
where name = 'Mahayil Aseer (Main Branch)';

insert into branches (name, city, address, phone, is_active)
select 'Mahayil Aseer (Main Branch)', 'Mahayil Aseer', 'Main branch address', '+966500000001', true
where not exists (
  select 1 from branches where name = 'Mahayil Aseer (Main Branch)'
);

update branches
set
  city = 'Abha',
  address = coalesce(address, 'Abha branch address'),
  phone = coalesce(phone, '+966500000002'),
  is_active = true
where name = 'Abha Branch';

insert into branches (name, city, address, phone, is_active)
select 'Abha Branch', 'Abha', 'Abha branch address', '+966500000002', true
where not exists (
  select 1 from branches where name = 'Abha Branch'
);

with category_seed(name, name_ar, sort_order) as (
  values
    ('Coffee', 'القهوة', 1),
    ('Spices', 'البهارات', 2),
    ('Herbs & Attar', 'الأعشاب والعطور', 3),
    ('Incense', 'البخور', 4),
    ('Nuts', 'المكسرات', 5),
    ('Dates', 'التمور', 6),
    ('Oils', 'الزيوت', 7)
)
update categories c
set
  name_ar = s.name_ar,
  sort_order = s.sort_order,
  is_active = true
from category_seed s
where c.name = s.name;

insert into categories (name, name_ar, sort_order, is_active)
select s.name, s.name_ar, s.sort_order, true
from (
  values
    ('Coffee', 'القهوة', 1),
    ('Spices', 'البهارات', 2),
    ('Herbs & Attar', 'الأعشاب والعطور', 3),
    ('Incense', 'البخور', 4),
    ('Nuts', 'المكسرات', 5),
    ('Dates', 'التمور', 6),
    ('Oils', 'الزيوت', 7)
) as s(name, name_ar, sort_order)
where not exists (
  select 1 from categories c where c.name = s.name
);

commit;
