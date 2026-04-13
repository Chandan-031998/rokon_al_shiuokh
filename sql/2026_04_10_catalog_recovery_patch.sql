-- Non-destructive recovery patch for customer catalog and cart compatibility
-- Purpose:
-- 1. Backfill schema columns introduced by the admin panel
-- 2. Restore starter branches/categories if missing
-- 3. Restore starter featured demo products if missing

begin;

alter table if exists products
  add column if not exists pack_size varchar(80);

alter table if exists branches
  add column if not exists pickup_available boolean not null default true,
  add column if not exists delivery_available boolean not null default true,
  add column if not exists delivery_coverage text;

insert into branches (name, city, address, phone, is_active)
select 'Mahayil Aseer (Main Branch)', 'Mahayil Aseer', 'Main branch address', '+966500000001', true
where not exists (
  select 1 from branches where name = 'Mahayil Aseer (Main Branch)'
);

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
insert into categories (name, name_ar, sort_order, is_active)
select s.name, s.name_ar, s.sort_order, true
from category_seed s
where not exists (
  select 1 from categories c where c.name = s.name
);

insert into products (
  category_id,
  branch_id,
  name,
  name_ar,
  sku,
  description,
  price,
  stock_qty,
  is_featured,
  is_active
)
select c.id, b.id, 'Premium Arabic Coffee', 'قهوة عربية فاخرة', 'COF-001', 'Starter demo product', 28.00, 100, true, true
from categories c
join branches b on b.name = 'Mahayil Aseer (Main Branch)'
where c.name = 'Coffee'
  and not exists (select 1 from products where sku = 'COF-001');

insert into products (
  category_id,
  branch_id,
  name,
  name_ar,
  sku,
  description,
  price,
  stock_qty,
  is_featured,
  is_active
)
select c.id, b.id, 'Luxury Saffron Mix', 'خلطة زعفران فاخرة', 'SPI-001', 'Starter demo product', 39.00, 80, true, true
from categories c
join branches b on b.name = 'Abha Branch'
where c.name = 'Spices'
  and not exists (select 1 from products where sku = 'SPI-001');

commit;
