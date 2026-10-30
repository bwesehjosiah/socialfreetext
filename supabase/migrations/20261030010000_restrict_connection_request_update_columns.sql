-- Restrict connection request responses to the status field only.
-- RLS still limits updates to the intended recipient and pending requests.
revoke update on table public.connection_requests from authenticated;
grant update (status) on table public.connection_requests to authenticated;
