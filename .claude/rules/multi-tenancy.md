# Multi-tenancy (mandatory)

Tenant isolation is enforced by Postgres Row Level Security. The tenant is the `org_id` claim of the signed JWT, read by `current_org_id()`.

- Never accept, send or trust `organization_id` from the client. Inserts set it in SQL with `current_org_id()`.
- Never use the service role key in `src/`. The frontend uses only `VITE_SUPABASE_ANON_KEY`.
- Every new business table must have:
  - `organization_id uuid not null references organizations(id)` (or reach it through a parent row, like `purchase_order_lines`)
  - `deleted_at timestamptz`
  - `alter table ... enable row level security`
  - a policy scoped by `current_org_id()` that also hides soft-deleted rows
- Postgres functions are `security invoker`, so RLS still applies inside them. Do not use `security definer` without an explicit reason written in the migration.
- Do not filter by organization in frontend queries to "be safe": RLS already does it, and a client-side filter hides missing policies.
