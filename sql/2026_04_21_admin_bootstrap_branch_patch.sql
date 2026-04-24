-- Add optional branch storage for bootstrap-created admin accounts.
-- Safe to run on an existing project before deploying the updated backend.

begin;

alter table if exists users
  add column if not exists branch varchar(120);

commit;
