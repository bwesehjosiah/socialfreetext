-- Social feed, story metadata, group conversations, and shared media storage.
-- All user-generated records are protected by authenticated RLS policies.

alter table public.statuses
  add column if not exists status_type text not null default 'text',
  add column if not exists background text,
  add column if not exists caption text,
  add column if not exists music text;
alter table public.statuses drop constraint if exists statuses_status_type_check;
alter table public.statuses add constraint statuses_status_type_check check (status_type in ('text','photo','video'));

create table if not exists public.feed_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  media_url text,
  media_type text check (media_type is null or media_type in ('image','video','document')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint feed_posts_body_or_media check (char_length(body) <= 5000 and (char_length(body) > 0 or media_url is not null))
);
create index if not exists feed_posts_created_at_idx on public.feed_posts(created_at desc);
create index if not exists feed_posts_user_created_idx on public.feed_posts(user_id, created_at desc);

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists feed_comments_post_created_idx on public.feed_comments(post_id, created_at);

create table if not exists public.feed_reactions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.feed_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null default '❤️' check (char_length(reaction) between 1 and 16),
  created_at timestamptz not null default now(),
  unique(post_id, user_id)
);

create table if not exists public.group_chats (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  description text not null default '' check (char_length(description) <= 500),
  avatar_url text,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.group_chat_members (
  group_id uuid not null references public.group_chats(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  joined_at timestamptz not null default now(),
  primary key(group_id,user_id)
);
create index if not exists group_chat_members_user_idx on public.group_chat_members(user_id, group_id);

create table if not exists public.group_chat_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.group_chats(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '',
  media_url text,
  media_type text check (media_type is null or media_type in ('image','video','document','audio')),
  created_at timestamptz not null default now(),
  constraint group_chat_messages_body_or_media check (char_length(body) <= 5000 and (char_length(body) > 0 or media_url is not null))
);
create index if not exists group_chat_messages_group_created_idx on public.group_chat_messages(group_id, created_at desc);

create table if not exists public.group_chat_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.group_chat_messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (char_length(reaction) between 1 and 16),
  created_at timestamptz not null default now(),
  unique(message_id,user_id)
);

alter table public.statuses enable row level security;
alter table public.feed_posts enable row level security;
alter table public.feed_comments enable row level security;
alter table public.feed_reactions enable row level security;
alter table public.group_chats enable row level security;
alter table public.group_chat_members enable row level security;
alter table public.group_chat_messages enable row level security;
alter table public.group_chat_reactions enable row level security;

drop policy if exists "Authenticated users can read active statuses" on public.statuses;
create policy "Authenticated users can read active statuses" on public.statuses for select to authenticated using (expires_at > now());
drop policy if exists "Users create own statuses" on public.statuses;
create policy "Users create own statuses" on public.statuses for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users delete own statuses" on public.statuses;
create policy "Users delete own statuses" on public.statuses for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Authenticated users read feed posts" on public.feed_posts;
create policy "Authenticated users read feed posts" on public.feed_posts for select to authenticated using (true);
drop policy if exists "Users create own feed posts" on public.feed_posts;
create policy "Users create own feed posts" on public.feed_posts for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users update own feed posts" on public.feed_posts;
create policy "Users update own feed posts" on public.feed_posts for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists "Users delete own feed posts" on public.feed_posts;
create policy "Users delete own feed posts" on public.feed_posts for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Authenticated users read feed comments" on public.feed_comments;
create policy "Authenticated users read feed comments" on public.feed_comments for select to authenticated using (true);
drop policy if exists "Users add own feed comments" on public.feed_comments;
create policy "Users add own feed comments" on public.feed_comments for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users delete own feed comments" on public.feed_comments;
create policy "Users delete own feed comments" on public.feed_comments for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Authenticated users read feed reactions" on public.feed_reactions;
create policy "Authenticated users read feed reactions" on public.feed_reactions for select to authenticated using (true);
drop policy if exists "Users manage own feed reactions" on public.feed_reactions;
create policy "Users manage own feed reactions" on public.feed_reactions for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "Group members read group chats" on public.group_chats;
create policy "Group members read group chats" on public.group_chats for select to authenticated using (exists (select 1 from public.group_chat_members m where m.group_id = id and m.user_id = (select auth.uid())));
drop policy if exists "Authenticated users create groups" on public.group_chats;
create policy "Authenticated users create groups" on public.group_chats for insert to authenticated with check (created_by = (select auth.uid()));
drop policy if exists "Group admins update groups" on public.group_chats;
create policy "Group admins update groups" on public.group_chats for update to authenticated using (exists (select 1 from public.group_chat_members m where m.group_id = id and m.user_id = (select auth.uid()) and m.role = 'admin')) with check (exists (select 1 from public.group_chat_members m where m.group_id = id and m.user_id = (select auth.uid()) and m.role = 'admin'));

drop policy if exists "Members read own group membership" on public.group_chat_members;
create policy "Members read own group membership" on public.group_chat_members for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Group creator adds first member" on public.group_chat_members;
create policy "Group creator adds first member" on public.group_chat_members for insert to authenticated with check (user_id = (select auth.uid()) or exists (select 1 from public.group_chat_members mine where mine.group_id = group_chat_members.group_id and mine.user_id = (select auth.uid()) and mine.role = 'admin'));
drop policy if exists "Group admins remove members" on public.group_chat_members;
create policy "Group admins remove members" on public.group_chat_members for delete to authenticated using (user_id = (select auth.uid()) or exists (select 1 from public.group_chat_members mine where mine.group_id = group_chat_members.group_id and mine.user_id = (select auth.uid()) and mine.role = 'admin'));

drop policy if exists "Group members read messages" on public.group_chat_messages;
create policy "Group members read messages" on public.group_chat_messages for select to authenticated using (exists (select 1 from public.group_chat_members m where m.group_id = group_chat_messages.group_id and m.user_id = (select auth.uid())));
drop policy if exists "Group members send messages" on public.group_chat_messages;
create policy "Group members send messages" on public.group_chat_messages for insert to authenticated with check (sender_id = (select auth.uid()) and exists (select 1 from public.group_chat_members m where m.group_id = group_chat_messages.group_id and m.user_id = (select auth.uid())));
drop policy if exists "Group message sender deletes own" on public.group_chat_messages;
create policy "Group message sender deletes own" on public.group_chat_messages for delete to authenticated using (sender_id = (select auth.uid()));

drop policy if exists "Group members read message reactions" on public.group_chat_reactions;
create policy "Group members read message reactions" on public.group_chat_reactions for select to authenticated using (exists (select 1 from public.group_chat_messages gm join public.group_chat_members m on m.group_id = gm.group_id where gm.id = message_id and m.user_id = (select auth.uid())));
drop policy if exists "Users manage own group reactions" on public.group_chat_reactions;
create policy "Users manage own group reactions" on public.group_chat_reactions for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('social-media','social-media',true,52428800,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','application/pdf','text/plain','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do nothing;
drop policy if exists "Social media files are publicly readable" on storage.objects;
create policy "Social media files are publicly readable" on storage.objects for select using (bucket_id = 'social-media');
drop policy if exists "Users upload own social media files" on storage.objects;
create policy "Users upload own social media files" on storage.objects for insert to authenticated with check (bucket_id = 'social-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Users update own social media files" on storage.objects;
create policy "Users update own social media files" on storage.objects for update to authenticated using (bucket_id = 'social-media' and (storage.foldername(name))[1] = (select auth.uid())::text) with check (bucket_id = 'social-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "Users delete own social media files" on storage.objects;
create policy "Users delete own social media files" on storage.objects for delete to authenticated using (bucket_id = 'social-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
