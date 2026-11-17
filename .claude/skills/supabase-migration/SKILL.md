---
name: supabase-migration
description: Supabase/Postgres migration conventions — file numbering and naming, table template with tenant RLS, soft delete with partial unique indexes, business logic as plpgsql RPC functions. Use whenever you add or change a table, column, index, enum, RLS policy or Postgres function, or anything under supabase/migrations/.
---

# Supabase migrations

## File naming

- Location: `supabase/migrations/`
- Name: `NNNN_snake_case_description.sql`, where `NNNN` is the highest existing number + 1, zero-padded to 4 digits. Check the folder first; do not guess.
- One logical change per file. Never edit a migration that already exists — add a new one.

## New table template

```sql
create table <name> (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  -- columns...
  created_by      uuid not null references auth.users(id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

alter table <name> enable row level security;

create policy <name>_tenant on <name>
  for all
  using (organization_id = current_org_id() and deleted_at is null)
  with check (organization_id = current_org_id());
```

Child tables without their own `organization_id` (like `purchase_order_lines`) get a policy that checks the parent row with `exists (...)`, including `deleted_at is null` on the parent.

## Indexes

- Unique constraints are partial, so a soft-deleted row does not block reuse:
  `create unique index <name>_<cols>_uq on <name> (organization_id, <col>) where deleted_at is null;`
- Index common filters with `organization_id` first, also `where deleted_at is null`.

## Business logic

- Multi-step writes and state changes are `plpgsql` functions with `security invoker`, called from the client via RPC.
- Tenant and user inside functions: `current_org_id()` and `auth.uid()`, never parameters.
- State machines: lock the row with `select ... for update`, validate the transition explicitly, `raise exception` with a readable message on an invalid one (see `transition_purchase_order` in `0008`).
- Money and quantities: `numeric(14,2)` with `check` constraints.

## After the migration

1. Regenerate types: `supabase gen types typescript` → `src/types/database.ts`.
2. Update `model.ts` of the affected feature if a new enum value or column needs a label or constant.
3. Run the `rls-reviewer` agent on the new migration.
