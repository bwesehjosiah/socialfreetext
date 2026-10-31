-- Advanced private messaging: delivery, edits, soft-delete and reactions.
begin;

alter table public.messages
  add column if not exists delivered_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists is_deleted boolean not null default false,
  add column if not exists deleted_at timestamptz;

grant update (body, updated_at, is_deleted, deleted_at) on public.messages to authenticated;
grant update (delivered_at, read_at) on public.messages to authenticated;

drop policy if exists "Senders can edit or delete their messages" on public.messages;
create policy "Senders can edit or delete their messages"
  on public.messages for update to authenticated
  using ((select auth.uid()) = sender_id)
  with check ((select auth.uid()) = sender_id);

drop policy if exists "Recipients can mark messages delivered or read" on public.messages;
create policy "Recipients can mark messages delivered or read"
  on public.messages for update to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('❤️','👍','😂','😮','😢','🔥')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

alter table public.message_reactions enable row level security;
revoke all on public.message_reactions from anon, authenticated;
grant select, insert, update, delete on public.message_reactions to authenticated;

drop policy if exists "Participants can view message reactions" on public.message_reactions;
create policy "Participants can view message reactions"
  on public.message_reactions for select to authenticated
  using (exists (
    select 1 from public.messages m
    where m.id = message_id
      and ((select auth.uid()) = m.sender_id or (select auth.uid()) = m.recipient_id)
  ));

drop policy if exists "Participants can add their own message reactions" on public.message_reactions;
create policy "Participants can add their own message reactions"
  on public.message_reactions for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.messages m
      where m.id = message_id
        and ((select auth.uid()) = m.sender_id or (select auth.uid()) = m.recipient_id)
    )
  );

drop policy if exists "Users can change their own message reactions" on public.message_reactions;
create policy "Users can change their own message reactions"
  on public.message_reactions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can remove their own message reactions" on public.message_reactions;
create policy "Users can remove their own message reactions"
  on public.message_reactions for delete to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.set_message_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists messages_set_updated_at on public.messages;
create trigger messages_set_updated_at
  before update of body, is_deleted on public.messages
  for each row execute procedure public.set_message_updated_at();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'message_reactions'
     ) then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end;
$$;

commit;
