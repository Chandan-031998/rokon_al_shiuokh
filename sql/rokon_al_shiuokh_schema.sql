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
  description text,
  price numeric(10,2) not null check (price >= 0),
  stock_qty integer not null default 0 check (stock_qty >= 0),
  image_url text,
  is_featured boolean not null default false,
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
