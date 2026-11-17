---
paths:
  - "src/**/*.{ts,tsx}"
---

# Frontend data access

- Supabase is called only from `src/features/<feature>/api.ts`. Components and hooks never import `supabase` for queries (the one exception: Realtime subscriptions in `hooks.ts`).
- `api.ts` functions throw on `error` and return plain data; they never swallow errors.
- Business operations (create, status transitions) call RPC functions via `supabase.rpc(...)`; only simple field updates use `.update()`.
- Soft delete = `.update({ deleted_at: new Date().toISOString() })`, never `.delete()`.
- Every feature exports a query key factory (`purchaseOrderKeys` pattern) from `hooks.ts`; never write key arrays inline.
- Mutations invalidate the feature's root key (`xxxKeys.all`) on success.
- Types come from `model.ts`, derived from `@/types/database`; do not hand-write row types.
