create table if not exists product_branch_availability (
  id bigserial primary key,
  product_id bigint not null references products(id) on delete cascade,
  branch_id bigint not null references branches(id) on delete cascade,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  unique (product_id, branch_id)
);

insert into product_branch_availability (
  product_id,
  branch_id,
  is_available
)
select
  p.id,
  p.branch_id,
  true
from products p
where p.branch_id is not null
  and not exists (
    select 1
    from product_branch_availability pba
    where pba.product_id = p.id
      and pba.branch_id = p.branch_id
  );
