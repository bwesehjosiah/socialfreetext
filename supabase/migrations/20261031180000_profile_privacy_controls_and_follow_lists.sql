-- Better user profiles: privacy controls and list-level access rules.
alter table public.profiles
  add column if not exists profile_visibility text not null default 'public',
  add column if not exists followers_visibility text not null default 'public',
  add column if not exists following_visibility text not null default 'public',
  add column if not exists show_online_status boolean not null default true;

alter table public.profiles
  drop constraint if exists profiles_profile_visibility_check,
  add constraint profiles_profile_visibility_check check (profile_visibility in ('public','connections','private')),
  drop constraint if exists profiles_followers_visibility_check,
  add constraint profiles_followers_visibility_check check (followers_visibility in ('public','connections','private')),
  drop constraint if exists profiles_following_visibility_check,
  add constraint profiles_following_visibility_check check (following_visibility in ('public','connections','private'));

grant update (profile_visibility, followers_visibility, following_visibility, show_online_status)
  on public.profiles to authenticated;

drop policy if exists "Signed-in users can view profiles" on public.profiles;
drop policy if exists "Signed in users can view profiles" on public.profiles;
create policy "Profiles visible according to owner privacy"
on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or profile_visibility = 'public'
  or (
    profile_visibility = 'connections'
    and exists (
      select 1 from public.connection_requests cr
      where cr.status = 'accepted'
        and (
          (cr.requester_id = (select auth.uid()) and cr.recipient_id = profiles.id)
          or
          (cr.recipient_id = (select auth.uid()) and cr.requester_id = profiles.id)
        )
    )
  )
);

drop policy if exists "Signed in users can view follows" on public.follows;
drop policy if exists "Follow lists visible according to profile privacy" on public.follows;
create policy "Follow lists visible according to profile privacy"
on public.follows for select to authenticated
using (
  follower_id = (select auth.uid())
  or following_id = (select auth.uid())
  or exists (
    select 1 from public.profiles p
    where p.id = follows.following_id
      and (
        p.followers_visibility = 'public'
        or (
          p.followers_visibility = 'connections'
          and exists (
            select 1 from public.connection_requests cr
            where cr.status = 'accepted'
              and (
                (cr.requester_id = (select auth.uid()) and cr.recipient_id = p.id)
                or (cr.recipient_id = (select auth.uid()) and cr.requester_id = p.id)
              )
          )
        )
      )
  )
  or exists (
    select 1 from public.profiles p
    where p.id = follows.follower_id
      and (
        p.following_visibility = 'public'
        or (
          p.following_visibility = 'connections'
          and exists (
            select 1 from public.connection_requests cr
            where cr.status = 'accepted'
              and (
                (cr.requester_id = (select auth.uid()) and cr.recipient_id = p.id)
                or (cr.recipient_id = (select auth.uid()) and cr.requester_id = p.id)
              )
          )
        )
      )
  )
);

create index if not exists profiles_visibility_idx on public.profiles(profile_visibility);
