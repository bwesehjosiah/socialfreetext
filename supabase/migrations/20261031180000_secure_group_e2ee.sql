-- Secure group membership and prepare client-side group E2EE.
-- Existing messages and memberships are retained; legacy plaintext rows remain readable to existing members.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_group_member(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id = (select auth.uid())
     and exists (
       select 1
       from public.group_chat_members m
       where m.group_id = p_group_id
         and m.user_id = p_user_id
     );
$$;

create or replace function private.is_group_admin(p_group_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id = (select auth.uid())
     and exists (
       select 1
       from public.group_chat_members m
       where m.group_id = p_group_id
         and m.user_id = p_user_id
         and m.role = 'admin'
     );
$$;

revoke all on function private.is_group_member(uuid, uuid) from public, anon;
revoke all on function private.is_group_admin(uuid, uuid) from public, anon;
grant execute on function private.is_group_member(uuid, uuid) to authenticated;
grant execute on function private.is_group_admin(uuid, uuid) to authenticated;

-- A member can see the membership roster for groups they belong to.
drop policy if exists "Members read own group membership" on public.group_chat_members;
create policy "Group members read group roster"
on public.group_chat_members for select to authenticated
using (private.is_group_member(group_id, (select auth.uid())));

-- Only the creator can add their own initial membership; existing admins can invite others.
drop policy if exists "Group creator adds first member" on public.group_chat_members;
create policy "Group creators and admins add members"
on public.group_chat_members for insert to authenticated
with check (
  (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.group_chats g
      where g.id = group_id and g.created_by = (select auth.uid())
    )
  )
  or private.is_group_admin(group_id, (select auth.uid()))
);

-- Members may leave; admins may remove any member from their own group.
drop policy if exists "Group admins remove members" on public.group_chat_members;
create policy "Members leave or group admins remove members"
on public.group_chat_members for delete to authenticated
using (
  user_id = (select auth.uid())
  or private.is_group_admin(group_id, (select auth.uid()))
);

-- Replace group visibility checks with the recursion-safe helper.
drop policy if exists "Group members read group chats" on public.group_chats;
create policy "Group members read group chats"
on public.group_chats for select to authenticated
using (private.is_group_member(id, (select auth.uid())));

drop policy if exists "Group admins update groups" on public.group_chats;
create policy "Group admins update groups"
on public.group_chats for update to authenticated
using (private.is_group_admin(id, (select auth.uid())))
with check (private.is_group_admin(id, (select auth.uid())));

-- Per-member encrypted copies of a random group AES key. The client wraps each
-- copy with the existing ECDH-derived DM key; plaintext group keys never reach Postgres.
create table if not exists public.group_chat_key_envelopes (
  group_id uuid not null references public.group_chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  key_epoch integer not null check (key_epoch > 0),
  wrapped_key jsonb not null,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id, key_epoch)
);

create index if not exists group_chat_key_envelopes_user_idx
on public.group_chat_key_envelopes(user_id, group_id, key_epoch desc);

alter table public.group_chat_key_envelopes enable row level security;

drop policy if exists "Members read own group key envelopes" on public.group_chat_key_envelopes;
create policy "Members read own group key envelopes"
on public.group_chat_key_envelopes for select to authenticated
using (
  user_id = (select auth.uid())
  and private.is_group_member(group_id, (select auth.uid()))
);

drop policy if exists "Group admins distribute key envelopes" on public.group_chat_key_envelopes;
create policy "Group admins distribute key envelopes"
on public.group_chat_key_envelopes for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.is_group_admin(group_id, (select auth.uid()))
  and private.is_group_member(group_id, user_id)
);

drop policy if exists "Group admins rotate key envelopes" on public.group_chat_key_envelopes;
create policy "Group admins rotate key envelopes"
on public.group_chat_key_envelopes for delete to authenticated
using (
  user_id = (select auth.uid())
  or private.is_group_admin(group_id, (select auth.uid()))
);

-- Mark historical rows as legacy (0). New writes must be authenticated ciphertext.
alter table public.group_chat_messages
  add column if not exists key_epoch integer not null default 1,
  add column if not exists encryption_version smallint not null default 0;

alter table public.group_chat_messages
  drop constraint if exists group_chat_messages_encrypted_payload_check;
alter table public.group_chat_messages
  add constraint group_chat_messages_encrypted_payload_check
  check (
    (encryption_version = 0)
    or (encryption_version = 1 and body like 'sftg1:%' and media_url is null)
  );

drop policy if exists "Group members send messages" on public.group_chat_messages;
create policy "Group members send encrypted messages"
on public.group_chat_messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and encryption_version = 1
  and body like 'sftg1:%'
  and media_url is null
  and private.is_group_member(group_id, (select auth.uid()))
  and exists (
    select 1 from public.group_chat_key_envelopes e
    where e.group_id = group_chat_messages.group_id
      and e.user_id = (select auth.uid())
      and e.key_epoch = group_chat_messages.key_epoch
  )
);
