# Supabase backend setup

This folder provides the first database schema for SocialfreeText, designed for Supabase Auth + Postgres Row Level Security (RLS).

## Included

- Supabase Auth handles passwords and sessions; passwords are not copied into public tables.
- A `profiles` table without password or email columns.
- Direct messages readable only by sender and recipient; inserts must be from the authenticated sender.
- Statuses that expire after 24 hours and are visible only while active to signed-in users.
- RLS enabled on each exposed table, with explicit grants and row policies.
- A profile row is created automatically when a Supabase Auth user is created.

## Setup

1. Create a project at https://supabase.com/dashboard.
2. Open **SQL Editor** and run the complete `schema.sql` file.
3. Under **Authentication → URL Configuration**, set the Site URL and allowed redirect URLs to the eventual website URL. Add your local development URL for testing.
4. Under **Authentication → Providers**, configure Email. Keep email confirmation enabled for a public-facing service unless you have a deliberate alternative.
5. Copy the project's **Project URL** and **publishable key** (older projects may label it `anon` key). A publishable/anon key is appropriate for browser use only with correct RLS policies.
6. Never put a Supabase **secret** or `service_role` key in HTML, JavaScript, GitHub, or a public build. Those keys bypass RLS.
7. Configure backups, abuse/rate limits, and email delivery before opening registration publicly.

## Important integration status

The existing `Index.html` is a large single-file prototype whose login, signup, password recovery, demo accounts, chats, and statuses are driven by browser `localStorage`. This migration creates a secure backend foundation, but **does not by itself switch the existing UI to Supabase**. The front end still needs a separate migration to replace local password checks and local-only state with Supabase Auth and database calls. Do not launch the existing login form for real users until that migration is complete.

Recommended frontend sequence:
1. Load the Supabase JavaScript client with a pinned version and initialize it with the project URL and publishable key.
2. Replace `S.users` password-based login/signup with `supabase.auth.signInWithPassword`, `supabase.auth.signUp`, `supabase.auth.resetPasswordForEmail`, and `supabase.auth.signOut`.
3. Resolve the current user using `supabase.auth.getSession()` / `onAuthStateChange`; use the Auth user UUID as `profiles.id`.
4. Replace local-only message/status persistence with queries to `messages` and `statuses`. Do not mirror passwords or sensitive tokens into application data.
5. Test RLS with two accounts to verify one user cannot read another user's private messages.
6. Add conversations/group membership and storage buckets with policies before implementing group chats or image uploads. The current schema intentionally does not expose group chat tables or media uploads yet.

## Deployment

The repository currently contains `Index.html` (capital I). GitHub Pages normally expects `index.html` at the published root. Before deployment, rename it to lowercase `index.html` (or configure the host's entry point) and verify dependencies and auth redirect URLs. Do not deploy until the UI is migrated off local demo authentication.
