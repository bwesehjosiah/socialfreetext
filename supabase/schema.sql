-- SocialfreeText: initial Supabase backend schema
-- Apply in Supabase Dashboard > SQL Editor.
-- Supabase Auth handles passwords and sessions; RLS protects database rows.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text not null default '',
  avatar_url text,
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (username is null or username ~ '^[a-zA-Z0-9_]{3,24}$'),
  constraint profiles_bio_length check (char_length(bio) <= 300)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint messages_not_self check (sender_id <> recipient_id),
  constraint messages_body_length check (char_length(body) between 1 and 5000)
);
create index if not exists messages_sender_created_idx on public.messages (sender_id, created_at desc);
create index if not exists messages_recipient_created_idx on public.messages (recipient_id, created_at desc);

create table if not exists public.statuses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  media_url text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint statuses_content_length check (char_length(content) between 1 and 2000),
  constraint statuses_media_url_length check (media_url is null or char_length(media_url) <= 2048)
);
create index if not exists statuses_recent_idx on public.statuses (created_at desc);
create index if not exists statuses_expiry_idx on public.statuses (expires_at);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  raw_username text;
  safe_username text;
begin
  raw_username := coalesce(new.raw_user_meta_data ->> 'username', split_part(coalesce(new.email, 'user'), '@', 1), 'user');
  safe_username := lower(left(regexp_replace(raw_username, '[^a-zA-Z0-9_]', '', 'g'), 17))
                   || '_' || left(replace(new.id::text, '-', ''), 6);
  insert into public.profiles (id, username, display_name, bio)
  values (
    new.id, safe_username,
    left(coalesce(new.raw_user_meta_data ->> 'display_name', raw_username, 'New user'), 80),
    left(coalesce(new.raw_user_meta_data ->> 'bio', ''), 300)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.messages enable row level security;
alter table public.statuses enable row level security;

revoke all on table public.profiles, public.messages, public.statuses from anon, authenticated;
grant select on table public.profiles to authenticated;
grant insert (id, username, display_name, avatar_url, bio) on table public.profiles to authenticated;
grant update (username, display_name, avatar_url, bio) on table public.profiles to authenticated;
grant select, insert on table public.messages to authenticated;
grant select, insert, update, delete on table public.statuses to authenticated;

drop policy if exists "Signed-in users can view profiles" on public.profiles;
create policy "Signed-in users can view profiles" on public.profiles for select to authenticated
using ((select auth.uid()) is not null);

drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile" on public.profiles for insert to authenticated
with check ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update to authenticated
using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists "Participants can read their messages" on public.messages;
create policy "Participants can read their messages" on public.messages for select to authenticated
using ((select auth.uid()) = sender_id or (select auth.uid()) = recipient_id);

drop policy if exists "Users can send as themselves" on public.messages;
create policy "Users can send as themselves" on public.messages for insert to authenticated
with check (
  (select auth.uid()) = sender_id and sender_id <> recipient_id
  and exists (select 1 from public.profiles p where p.id = recipient_id)
);

drop policy if exists "Signed-in users can view active statuses" on public.statuses;
create policy "Signed-in users can view active statuses" on public.statuses for select to authenticated
using (expires_at > now());

drop policy if exists "Users can create their own statuses" on public.statuses;
create policy "Users can create their own statuses" on public.statuses for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own statuses" on public.statuses;
create policy "Users can update their own statuses" on public.statuses for update to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own statuses" on public.statuses;
create policy "Users can delete their own statuses" on public.statuses for delete to authenticated
using ((select auth.uid()) = user_id);

-- No anonymous table access. Never place a Supabase secret/service_role key in the browser.
