# Supabase backend setup

This folder contains the initial Supabase Auth + Postgres Row Level Security (RLS) backend foundation for SocialfreeText.

## What is integrated in the HTML

`Index.html` now uses Supabase Auth for email/password sign-in, registration, password-reset email requests, session restoration, and sign-out. It does **not** use the old local password checks for these flows.

## Setup required before authentication can work

1. Create a project at https://supabase.com/dashboard.
2. Open **SQL Editor** and run the complete `schema.sql` file.
3. In `Index.html`, find `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` and replace the placeholders with your project's Project URL and publishable key (older projects may call it the `anon` key).
4. Under **Authentication → URL Configuration**, set the Site URL and allowed redirect URLs for local testing and the eventual website.
5. Under **Authentication → Providers**, configure Email and the email confirmation behavior you want. Password reset and confirmation links must point to a URL where this app is hosted.
6. Never put a Supabase **secret** or `service_role` key in HTML, JavaScript, GitHub, or any public build. Those keys bypass RLS.

Until the project URL/key are set and `schema.sql` has been applied, the app intentionally stays at the sign-in screen and reports that setup is required. I cannot create or configure a Supabase project inside your account without access to that project; no credentials have been guessed or committed.

## Important limitations — not production-ready yet

- Authentication is connected in code, but has not been tested against a live Supabase project.
- The existing chats, groups, calls, admin tools, AI history, and statuses still largely use local prototype state. They are **not** yet synchronized between users or devices.
- The current schema supports direct messages and statuses, but the HTML has not yet been migrated to read/write them through the database.
- The UI still contains prototype-only features (including local admin/role behavior) that must not be treated as server-authorized.
- Password-reset links currently request a reset email; the password recovery callback/update-password screen still needs to be implemented and tested.
- Username-based sign-in is not yet implemented; sign in using the account email.
- Use a two-account RLS test before any public launch.

## Next migration steps

1. Connect profile editing to `public.profiles` and enforce username uniqueness.
2. Replace local message/status persistence with `messages` and `statuses` queries; add real-time updates and pagination.
3. Add server-backed group membership, media storage policies, blocking/reporting, and moderation before exposing those features publicly.
4. Test signup, email confirmation, reset-password completion, sign-in, sign-out, and message isolation using separate accounts.

## Deployment

The repository currently contains `Index.html` (capital I). GitHub Pages normally expects `index.html` at the published root. Before deployment, rename it to lowercase `index.html` (or configure the host's entry point) and verify all auth redirect URLs. Do not advertise online messaging as live until the data layer is migrated.
