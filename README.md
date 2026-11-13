# purchasing-app — Purchase Orders Code Sample (React + Supabase)

This sample reproduces, on a React + Supabase stack, the procurement module we maintain in
production for a B2B SaaS product. The production code is under NDA, so names and details here
are generalized.

**What it demonstrates**

- Multi-tenancy enforced by Postgres Row Level Security — the tenant comes from the signed JWT, never from the client payload
- Order lifecycle as a state machine, with transitions validated inside the database
- Soft deletes with partial unique indexes
- Server state with TanStack React Query, kept fresh by Supabase Realtime

**Structure**

1. Database schema and RLS
2. Business logic as Postgres functions (RPC)
3. Supabase client and types
4. Data-access layer
5. React Query hooks and Realtime
6. UI
