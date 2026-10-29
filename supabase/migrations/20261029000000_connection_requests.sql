create table if not exists public.connection_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint connection_requests_not_self check (requester_id <> recipient_id),
  constraint connection_requests_pair_unique unique (requester_id, recipient_id)
);
create index if not exists connection_requests_recipient_status_idx on public.connection_requests (recipient_id, status, created_at desc);
create index if not exists connection_requests_requester_status_idx on public.connection_requests (requester_id, status, created_at desc);
alter table public.connection_requests enable row level security;
revoke all on table public.connection_requests from anon, authenticated;
grant select, insert, update on table public.connection_requests to authenticated;
drop policy if exists "Participants can read connection requests" on public.connection_requests;
create policy "Participants can read connection requests" on public.connection_requests for select to authenticated
using ((select auth.uid()) = requester_id or (select auth.uid()) = recipient_id);
drop policy if exists "Users can request a connection" on public.connection_requests;
create policy "Users can request a connection" on public.connection_requests for insert to authenticated
with check ((select auth.uid()) = requester_id and requester_id <> recipient_id and status = 'pending');
drop policy if exists "Recipient can respond to requests" on public.connection_requests;
create policy "Recipient can respond to requests" on public.connection_requests for update to authenticated
using ((select auth.uid()) = recipient_id and status = 'pending')
with check ((select auth.uid()) = recipient_id and status in ('accepted','declined'));
drop trigger if exists connection_requests_set_updated_at on public.connection_requests;
create trigger connection_requests_set_updated_at before update on public.connection_requests
for each row execute procedure public.set_updated_at();
do $$
begin
  alter publication supabase_realtime add table public.connection_requests;
exception when duplicate_object then null;
when undefined_object then null;
end $$;