-- Shared push endpoints, Android device tokens, unread counts, and call history.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  subscription jsonb not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions(user_id);

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android','ios')),
  device_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists device_push_tokens_user_idx on public.device_push_tokens(user_id);

create table if not exists public.call_logs (
  id uuid primary key default gen_random_uuid(),
  caller_id uuid not null references auth.users(id) on delete cascade,
  callee_id uuid not null references auth.users(id) on delete cascade,
  call_type text not null check (call_type in ('audio','video')),
  status text not null default 'ringing' check (status in ('ringing','answered','missed','rejected','cancelled','completed','failed')),
  started_at timestamptz not null default now(),
  answered_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  created_at timestamptz not null default now(),
  constraint call_logs_not_self check (caller_id <> callee_id)
);
create index if not exists call_logs_caller_created_idx on public.call_logs(caller_id, created_at desc);
create index if not exists call_logs_callee_created_idx on public.call_logs(callee_id, created_at desc);

alter table public.push_subscriptions enable row level security;
alter table public.device_push_tokens enable row level security;
alter table public.call_logs enable row level security;

revoke all on public.push_subscriptions, public.device_push_tokens, public.call_logs from anon, authenticated;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant select, insert, update, delete on public.device_push_tokens to authenticated;
grant select, insert, update on public.call_logs to authenticated;

drop policy if exists "Users manage own web push subscriptions" on public.push_subscriptions;
create policy "Users manage own web push subscriptions" on public.push_subscriptions
for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users manage own device push tokens" on public.device_push_tokens;
create policy "Users manage own device push tokens" on public.device_push_tokens
for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Call participants can read call logs" on public.call_logs;
create policy "Call participants can read call logs" on public.call_logs
for select to authenticated using (auth.uid() = caller_id or auth.uid() = callee_id);

drop policy if exists "Caller can create call log" on public.call_logs;
create policy "Caller can create call log" on public.call_logs
for insert to authenticated with check (auth.uid() = caller_id);

drop policy if exists "Participants can update call log" on public.call_logs;
create policy "Participants can update call log" on public.call_logs
for update to authenticated using (auth.uid() = caller_id or auth.uid() = callee_id)
with check (auth.uid() = caller_id or auth.uid() = callee_id);

create or replace view public.unread_message_counts
with (security_invoker = true) as
select recipient_id as user_id, sender_id as other_user_id, count(*)::bigint as unread_count
from public.messages
where read_at is null
group by recipient_id, sender_id;

grant select on public.unread_message_counts to authenticated;
