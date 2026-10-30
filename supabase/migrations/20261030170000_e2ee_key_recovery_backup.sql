create table if not exists public.e2ee_key_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  backup jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint e2ee_key_backup_size check (pg_column_size(backup) <= 16384)
);

alter table public.e2ee_key_backups enable row level security;
revoke all on table public.e2ee_key_backups from anon, authenticated;
grant select, insert, update, delete on table public.e2ee_key_backups to authenticated;

drop policy if exists "Users can read their own E2EE backup" on public.e2ee_key_backups;
create policy "Users can read their own E2EE backup"
on public.e2ee_key_backups for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own E2EE backup" on public.e2ee_key_backups;
create policy "Users can create their own E2EE backup"
on public.e2ee_key_backups for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own E2EE backup" on public.e2ee_key_backups;
create policy "Users can update their own E2EE backup"
on public.e2ee_key_backups for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own E2EE backup" on public.e2ee_key_backups;
create policy "Users can delete their own E2EE backup"
on public.e2ee_key_backups for delete to authenticated
using ((select auth.uid()) = user_id);

drop trigger if exists e2ee_key_backups_set_updated_at on public.e2ee_key_backups;
create trigger e2ee_key_backups_set_updated_at
before update on public.e2ee_key_backups
for each row execute procedure public.set_updated_at();
