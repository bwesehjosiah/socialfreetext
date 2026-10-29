# SocialfreeText

**SocialfreeText — Chat, Status, Calls, and AI Hub**

This repository currently contains a single-file HTML prototype (`Index.html`). Its existing interface is primarily a browser-local demo and is not yet ready for real user accounts or private online messaging.

## Backend foundation

The `supabase/` folder contains an initial Supabase schema and setup guide:

- `supabase/schema.sql` — profiles, direct messages, expiring statuses, explicit grants, and Row Level Security (RLS) policies.
- `supabase/README.md` — setup steps and the required frontend migration sequence.

### Current status

The schema is a foundation, not a completed production integration. The current HTML still uses localStorage for demo users, passwords, messages, and statuses. Do not use it for real user credentials until the UI is migrated to Supabase Auth and the database. Never commit a Supabase secret or `service_role` key.

## Run it

You can open the HTML file locally for a prototype preview. For production hosting, configure a static host and use lowercase `index.html` as the entry page. Set the production URL in Supabase Auth redirect settings after deployment.
