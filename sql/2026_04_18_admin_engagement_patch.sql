-- Admin engagement patch
-- Adds review moderation and wishlist support for customer engagement.

begin;

create table if not exists reviews (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  product_id bigint not null references products(id) on delete cascade,
  order_id bigint references orders(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  title varchar(180),
  body text,
  moderation_status varchar(30) not null default 'pending',
  moderation_notes text,
  is_verified_purchase boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_moderation_status_check
    check (moderation_status in ('pending', 'approved', 'rejected'))
);

create table if not exists wishlist_items (
  id bigserial primary key,
  user_id bigint not null references users(id) on delete cascade,
  product_id bigint not null references products(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint wishlist_items_user_product_key unique (user_id, product_id)
);

create index if not exists idx_reviews_product_status
  on reviews(product_id, moderation_status, created_at desc);
create index if not exists idx_reviews_user
  on reviews(user_id, created_at desc);
create index if not exists idx_reviews_rating
  on reviews(rating);
create index if not exists idx_wishlist_user_created
  on wishlist_items(user_id, created_at desc);

commit;
