-- Read the tenant from app_metadata.org_id instead of a top-level org_id claim.
--
-- Supabase Auth copies auth.users.raw_app_meta_data into every access token as
-- the app_metadata claim. Only the service role can change app_metadata (users
-- can change user_metadata, never app_metadata), so a user cannot move
-- themselves into another organization. Real sign-ins now carry the tenant
-- without a Custom Access Token Hook; before this, no issued token had a
-- top-level org_id, so current_org_id() was null and signed-in users saw nothing.
--
-- Changing a user's organization takes effect on their next token refresh.

create or replace function current_org_id() returns uuid
language sql stable as $$
  select (auth.jwt() -> 'app_metadata' ->> 'org_id')::uuid
$$;
