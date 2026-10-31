begin;

-- Use one participant-scoped UPDATE policy; column grants still limit which
-- fields senders and recipients can modify.
drop policy if exists "Recipients can mark messages read" on public.messages;
drop policy if exists "Recipients can mark messages delivered or read" on public.messages;
drop policy if exists "Senders can edit or delete their messages" on public.messages;
create policy "Participants can update message metadata"
  on public.messages for update to authenticated
  using ((select auth.uid()) = sender_id or (select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = sender_id or (select auth.uid()) = recipient_id);

create index if not exists message_reactions_user_id_idx
  on public.message_reactions(user_id);

commit;