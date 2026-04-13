begin;

update storage.buckets
set public = true
where id = 'products';

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Products bucket public read'
  ) then
    create policy "Products bucket public read"
    on storage.objects
    for select
    to anon, authenticated
    using (bucket_id = 'products');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Products bucket upload access'
  ) then
    create policy "Products bucket upload access"
    on storage.objects
    for insert
    to anon, authenticated
    with check (bucket_id = 'products');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Products bucket update access'
  ) then
    create policy "Products bucket update access"
    on storage.objects
    for update
    to anon, authenticated
    using (bucket_id = 'products')
    with check (bucket_id = 'products');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Products bucket delete access'
  ) then
    create policy "Products bucket delete access"
    on storage.objects
    for delete
    to anon, authenticated
    using (bucket_id = 'products');
  end if;
end $$;

commit;
