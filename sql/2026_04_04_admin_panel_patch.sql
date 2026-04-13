-- Non-destructive admin panel patch for Rokon Al Shioukh
-- Safe to run after the base schema.

begin;

alter table if exists users
  alter column role set default 'customer';

alter table if exists products
  add column if not exists pack_size varchar(80);

alter table if exists branches
  add column if not exists pickup_available boolean not null default true,
  add column if not exists delivery_available boolean not null default true,
  add column if not exists delivery_coverage text;

alter table if exists orders
  add column if not exists admin_notes text;

alter table if exists offers
  add column if not exists subtitle varchar(180),
  add column if not exists product_id bigint references products(id) on delete set null,
  add column if not exists category_id bigint references categories(id) on delete set null,
  add column if not exists branch_id bigint references branches(id) on delete set null;

create index if not exists idx_users_role on users(role);
create index if not exists idx_products_featured_active on products(is_featured, is_active);
create index if not exists idx_products_name on products(name);
create index if not exists idx_products_pack_size on products(pack_size);
create index if not exists idx_orders_status_branch on orders(order_status, branch_id);
create index if not exists idx_offers_active on offers(is_active);

update branches
set
  pickup_available = coalesce(pickup_available, true),
  delivery_available = coalesce(delivery_available, true)
where true;

commit;
