-- Admin discovery system patch
-- Adds configurable search terms, filters, and product discovery metadata.

begin;

alter table if exists products
  add column if not exists search_keywords text,
  add column if not exists search_synonyms text,
  add column if not exists is_hidden_from_search boolean not null default false;

create table if not exists search_terms (
  id bigserial primary key,
  term varchar(160) not null unique,
  term_type varchar(30) not null default 'popular',
  synonyms text,
  linked_category_id bigint references categories(id) on delete set null,
  linked_product_id bigint references products(id) on delete set null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint search_terms_term_type_check
    check (term_type in ('popular', 'featured'))
);

create table if not exists filter_groups (
  id bigserial primary key,
  name varchar(140) not null,
  slug varchar(160) not null unique,
  filter_type varchar(40) not null default 'multi_select',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint filter_groups_filter_type_check
    check (filter_type in ('multi_select', 'single_select', 'swatch', 'bucket'))
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

create index if not exists idx_products_hidden_search
  on products(is_hidden_from_search, is_active);
create index if not exists idx_products_search_keywords
  on products using gin (to_tsvector('simple', coalesce(search_keywords, '')));
create index if not exists idx_products_search_synonyms
  on products using gin (to_tsvector('simple', coalesce(search_synonyms, '')));
create index if not exists idx_search_terms_type_sort
  on search_terms(term_type, sort_order, is_active);
create index if not exists idx_filter_groups_sort
  on filter_groups(sort_order, is_active);
create index if not exists idx_filter_values_group_sort
  on filter_values(group_id, sort_order, is_active);
create index if not exists idx_product_filter_map_value
  on product_filter_map(filter_value_id, product_id);

insert into search_terms (term, term_type, synonyms, sort_order, is_active)
select * from (
  values
    ('arabic coffee', 'popular', 'gahwa,qahwa,coffee', 1, true),
    ('saffron', 'featured', 'zafaran,spice', 2, true),
    ('incense', 'popular', 'bukhoor,bakhour', 3, true)
) as seed(term, term_type, synonyms, sort_order, is_active)
where not exists (
  select 1 from search_terms existing where lower(existing.term) = lower(seed.term)
);

commit;
