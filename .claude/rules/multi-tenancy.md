# Multi-tenancy (mandatory)

Tenant isolation is enforced by Postgres Row Level Security. The tenant is `app_metadata.org_id` in the signed JWT, read by `current_org_id()`. Supabase Auth copies `auth.users.raw_app_meta_data` into the token; only the service role can change it. Never read the tenant from `user_metadata` (users can edit it) or from a top-level claim.

- Never accept, send or trust `organization_id` from the client. Inserts set it in SQL with `current_org_id()`.
- Never use the service role key in `src/` or in Edge Functions. The frontend uses only `VITE_SUPABASE_ANON_KEY`; an Edge Function builds its client with the anon key and the caller's `Authorization` header, so RLS applies to it too.
- Every new business table must have:
  - `organization_id uuid not null references organizations(id)` (or reach it through a parent row, like `purchase_order_lines`)
  - `deleted_at timestamptz`
  - `alter table ... enable row level security`
  - a policy scoped by `current_org_id()` that also hides soft-deleted rows
- Postgres functions are `security invoker`, so RLS still applies inside them. Do not use `security definer` without an explicit reason written in the migration.
- Do not filter by organization in frontend queries to "be safe": RLS already does it, and a client-side filter hides missing policies.
