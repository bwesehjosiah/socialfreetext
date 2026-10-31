-- Track the active group key epoch and pause sends while an admin rotates keys.
alter table public.group_chats
  add column if not exists key_epoch integer not null default 1,
  add column if not exists key_rotation_pending boolean not null default false;

drop policy if exists "Group members send encrypted messages" on public.group_chat_messages;
create policy "Group members send encrypted messages"
on public.group_chat_messages for insert to authenticated
with check (
  sender_id = (select auth.uid())
  and encryption_version = 1
  and body like 'sftg1:%'
  and media_url is null
  and private.is_group_member(group_id, (select auth.uid()))
  and exists (
    select 1 from public.group_chats g
    where g.id = group_chat_messages.group_id
      and g.key_epoch = group_chat_messages.key_epoch
      and g.key_rotation_pending = false
  )
  and exists (
    select 1 from public.group_chat_key_envelopes e
    where e.group_id = group_chat_messages.group_id
      and e.user_id = (select auth.uid())
      and e.key_epoch = group_chat_messages.key_epoch
  )
);

create index if not exists group_chat_key_envelopes_created_by_idx
on public.group_chat_key_envelopes(created_by);
