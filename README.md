# SocialfreeText

**SocialfreeText — Chat, Status, Calls, and AI Hub**

This repository contains a single-file HTML prototype (`Index.html`) with a Supabase authentication integration scaffold. It is not yet a production-ready social messaging service.

## Current status

- Supabase email/password sign-in, registration, session restoration, password-reset email requests, and sign-out are wired in the frontend code.
- You must create your own Supabase project, apply `supabase/schema.sql`, and replace the configuration placeholders in `Index.html` with the Project URL and publishable key before authentication can work.
- Chats, groups, calls, admin tools, AI history, and statuses still largely use browser-local prototype state. Messages and statuses are not yet synchronized online between users/devices.
- The authentication integration has not been tested against a live Supabase project. Do not launch or invite real users yet.

## Backend setup

See `supabase/README.md` for the setup checklist, security notes, and remaining migration work.

- `supabase/schema.sql` — profiles, direct messages, expiring statuses, grants, and Row Level Security (RLS) policies.
- `supabase/README.md` — project configuration and integration status.

**Security:** Never store passwords in app tables or commit a Supabase secret / `service_role` key. Only a publishable (or legacy anon) key belongs in browser code, protected by correct RLS policies.

## Preview and hosting

You can open `Index.html` locally for a UI preview. For common static hosts such as GitHub Pages, use lowercase `index.html` as the entry page and configure the production URL in Supabase Auth redirect settings.
