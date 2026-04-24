create table if not exists product_images (
  id bigserial primary key,
  product_id bigint not null references products(id) on delete cascade,
  image_url text not null,
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_product_images_product_sort
  on product_images(product_id, sort_order, id);

create unique index if not exists uq_product_images_primary_per_product
  on product_images(product_id)
  where is_primary is true;

insert into product_images (product_id, image_url, sort_order, is_primary)
select
  p.id,
  p.image_url,
  0,
  true
from products p
where coalesce(trim(p.image_url), '') <> ''
  and not exists (
    select 1
    from product_images pi
    where pi.product_id = p.id
      and pi.image_url = p.image_url
  );

with ranked_images as (
  select
    id,
    product_id,
    row_number() over (
      partition by product_id
      order by
        case when is_primary then 0 else 1 end,
        sort_order asc,
        id asc
    ) as position_rank
  from product_images
)
update product_images pi
set is_primary = ranked_images.position_rank = 1
from ranked_images
where ranked_images.id = pi.id;
