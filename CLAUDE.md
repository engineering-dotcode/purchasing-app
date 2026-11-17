# purchasing-app

Purchase orders module: React + TanStack React Query on the frontend, Supabase (Postgres, RLS, RPC, Realtime) on the backend. Multi-tenant: every row belongs to an organization.

## Structure

- `supabase/migrations/` — numbered SQL migrations (`NNNN_snake_case.sql`), schema + RLS + Postgres functions
- `src/lib/supabase.ts` — the single Supabase client (anon key only)
- `src/features/<feature>/` — one folder per feature:
  - `model.ts` — types derived from `@/types/database` and domain constants
  - `api.ts` — all Supabase queries and RPC calls for the feature
  - `hooks.ts` — React Query hooks, query key factory, Realtime subscriptions
  - `*.tsx` — UI components
- `src/hooks/` — shared generic hooks
- `src/types/database.ts` — generated, never edit by hand: `supabase gen types typescript`

## Critical rules

1. **Tenant comes from the JWT only.** Postgres resolves it with `current_org_id()`. Never send `organization_id` from the client. Details: `.claude/rules/multi-tenancy.md`.
2. **Soft delete only.** Set `deleted_at`; never `DELETE` business rows. Unique indexes are partial: `where deleted_at is null`.
3. **Status changes go through the database.** Use the `transition_purchase_order` RPC; never update `status` directly. Allowed transitions live in that function.
4. **Never edit an applied migration.** Add a new one with the next number.
5. Frontend data-access conventions: `.claude/rules/frontend-data.md` (loads when working in `src/`).

## Working here

- Any schema change (table, column, index, policy, function) → follow the `supabase-migration` skill.
- After schema or RLS changes → run the `rls-reviewer` agent before finishing.
