 # purchasing-app

  A multi-tenant purchase-order module.
  **Stack:** React + TanStack React Query, Supabase (Postgres, RLS, RPC, Realtime, Edge Functions).

  The first half of this README describes what the module does and how it is tested. The second half shows how Claude Code is wired into the same work.

  ## What the module does

  | Area | What it gives you | Where it lives |
  |---|---|---|
  | Purchase orders | Orders with lines, per-organization numbers (`PO-000001`), a status workflow | `supabase/migrations/0007`–`0009` |
  | Multi-tenancy | Every organization sees only its own rows, enforced by Postgres RLS | `current_org_id()` in `0010`, policies in every migration |
  | Send to vendor | One click submits the order and emails the vendor, with retry | `supabase/functions/submit-purchase-order/`, `0011` |
  | UI | Order list with search, paging, live updates, "Submit to vendor" / "Retry email" | `src/features/purchase-orders/` |

  ### Purchase orders

  - Statuses: `DRAFT` → `PENDING_APPROVAL` → `SUBMITTED` → `CONFIRMED` → `PARTIALLY_RECEIVED` → `RECEIVED`, plus `CANCELLED` and `REJECTED`.
  - Every status change goes through the `transition_purchase_order` RPC, which holds the allowed transitions. `SUBMITTED` additionally needs a queued vendor email, so it is reached only through `submit_purchase_order`.
  - Orders are created by the `create_purchase_order` RPC. Numbers are counted per organization, so two organizations both have a `PO-000001`.
  - Delete is soft (`deleted_at`) through the `archive_purchase_order` RPC; soft-deleted rows disappear for everyone.

  ### Multi-tenancy

  - The tenant is `app_metadata.org_id` in the signed JWT, read by `current_org_id()` (migration `0010`). Supabase Auth copies it from `auth.users.raw_app_meta_data`, and only the service role can change it, so a user cannot move themselves into another organization. A new user needs `org_id` in app_metadata, set by an admin.
  - Every table has RLS and a policy scoped by `current_org_id()` that also hides soft-deleted rows. The client never sends `organization_id`.
  - Foreign keys cannot point at another organization's rows: composite keys for vendors and orders, a trigger for order lines (`0009`).

  ### Edge Function: submit-purchase-order

  `POST /functions/v1/submit-purchase-order` with `{ "orderId": "..." }` sends an order to its vendor. The UI calls it from the "Submit to vendor" / "Retry email" button.

  1. `submit_purchase_order` RPC: queues one row in `purchase_order_emails` and moves the order to SUBMITTED, in one transaction. Vendor without email or order without lines → 422, nothing changes.
  2. The function sends the email (Resend) and records the attempt. If the provider fails: 502, the order stays SUBMITTED, the email stays unsent with its error; calling the function again retries it. A sent email is final (409).
  3. Runs with the caller's JWT and the anon key, so RLS applies: another organization's order → 404. The service role key is never used.

  Secrets on the Supabase project: `RESEND_API_KEY`, optional `EMAIL_FROM`. `DRY_RUN=true` sends nothing and returns the email in the response (dev only). Without a key and without `DRY_RUN` every attempt fails with 502 and stays retryable.

  The outbox is read-only for clients: only `submit_purchase_order` and `record_purchase_order_email_attempt` write it.

  **Try it:** locally, `npx supabase db reset` and `./scripts/test-edge-functions.sh` run every scenario below. On the dev project (`DRY_RUN=true`), call the function with the access token of `buyer@acme.test` for `PO-000001`: the response contains the email for `orders@freshfarms.test`. The repository has no app entry point yet, so the UI components are not runnable on their own.

  ## Tests

  | Suite | What it checks | Run locally |
  |---|---|---|
  | Unit (vitest) | Status helpers in `model.ts`: allowed transitions, closed statuses, labels, unsent email | `npm test` |
  | Database (pgTAP), 70 checks | Tenant isolation, status transitions, integrity, email outbox | `npx supabase test db` |
  | Edge Function (end-to-end), 7 scenarios | The deployed function against the local stack, with a mock email provider | `./scripts/test-edge-functions.sh` |

  ### Database tests (`supabase/tests/`)

  Each file signs in as a seed user (Acme Foods or Globex Retail) by setting JWT claims, runs as `authenticated`, and rolls back at the end.

  - `001_tenant_read.sql` — a user sees only their organization's rows, never soft-deleted ones, nothing without `app_metadata.org_id`; a top-level or `user_metadata.org_id` claim is ignored.
  - `002_tenant_write.sql` — a user cannot create, change or soft-delete another organization's rows, or move their own rows into one.
  - `003_transition_purchase_order.sql` — allowed transitions pass, forbidden ones raise, SUBMITTED only through `submit_purchase_order`, another organization's order is not found.
  - `004_integrity.sql` — no cross-organization references, per-organization order numbers, soft delete.
  - `005_purchase_order_emails.sql` — one email per submit, attempts recorded, a sent email is final, direct writes to the outbox are rejected, other organizations cannot see or touch it.

  ### Edge Function tests (`supabase/functions/*/e2e.mjs`)

  `scripts/test-edge-functions.sh` serves the functions locally, points `RESEND_API_URL` at a mock email server in the test, and runs `node --test`. It signs its own tokens with the local JWT secret, in the same shape Supabase Auth issues.

  Scenarios: no token → 401; another organization's order → 404; submit → 200 and exactly one email; repeat → 409; the other organization cannot see the email row; provider down → 502, then retry → 200; non-submittable status → 409.

  The tests change seed data, so run them on a fresh `npx supabase db reset`.

  ### CI (`.github/workflows/ci.yml`)

  | Job | What it runs |
  |---|---|
  | `build` | vitest, with a JUnit report |
  | `db-tests` | `supabase start` (only the services the tests need), then pgTAP, then the Edge Function tests. About 1–2 minutes, no secrets |
  | `analyze-failures` | Only when a job above fails on a PR, see 04 below |

  ### Running locally

  ```bash
  npx supabase start                    # Postgres, API, Auth, Edge runtime in Docker; applies migrations and seed.sql
  npx supabase db reset                 # fresh seed data
  npx supabase test db                  # pgTAP
  ./scripts/test-edge-functions.sh      # Edge Function end-to-end
  npm test                              # vitest
  ```

  Deploy to the dev project: `npx supabase db push`, `npx supabase functions deploy submit-purchase-order`, secrets with `npx supabase secrets set`.

  ## How we work with Claude Code

  The repository has five practices set up. Each one works automatically as soon as you open Claude Code in the project root, or on every pull request.

  | # | Practice | What it gives you | Where it lives |
  |---|---|---|---|
  | 01 | Rules files | Claude knows the project rules without being reminded | `CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, `.claude/agents/` |
  | 02 | Hooks | Applied migrations cannot be edited | `.claude/settings.json`, `.claude/hooks/protect-migrations.sh` |
  | 03 | MCP | Claude reads the live dev schema and data instead of guessing | `.mcp.json` |
  | 04 | Claude in CI | The cause of a test failure arrives as a PR comment | `.github/workflows/ci.yml` |
  | 05 | AI review | Every PR gets one review comment against the project rules | `.github/workflows/ai-review.yml` |

  ### 01 · Rules files

  - `CLAUDE.md` always loads. It gives a short stack overview and the critical rules: tenant only from the JWT, soft delete, status changes via RPC, never edit migrations, Edge Functions run as the caller.
  - `.claude/rules/multi-tenancy.md` also always loads: the tenant is `app_metadata.org_id`, every new table has `organization_id`, `deleted_at` and RLS, and the service role key is banned from `src/` and from Edge Functions.
  - `.claude/rules/frontend-data.md` loads only for `src/**/*.{ts,tsx}`. Supabase is called only from `api.ts`, and query keys come from a key factory.
  - Claude loads the `supabase-migration` skill when a task touches the schema.
  - The read-only `rls-reviewer` subagent checks organization isolation after every schema change, including Edge Functions.

  **Try it:** ask "add a warehouses table". Claude should create the next numbered migration with RLS and then run `rls-reviewer`.

  ### 02 · Hooks

  Before every `Edit`/`Write`, Claude Code runs `protect-migrations.sh`. If a file in `supabase/migrations/*.sql` is already in git, the edit is blocked (exit 2) and Claude creates a new migration instead. Migrations that are not committed yet can be edited freely.

  **Try it:** ask "add a currency column to 0007_purchase_orders.sql". Expect `Blocked: … is already committed` and a new `0012_…sql` file.

  ### 03 · MCP (Supabase, read-only)

  The official hosted Supabase MCP server is connected to the **dev project** with `read_only=true` and only the tool groups we need. Authentication is OAuth, so the repository holds no tokens.

  **First run:** open Claude Code, approve the `supabase` server, then run `/mcp` → `supabase` → sign in through the browser.

  **Limitations:**
  - MCP bypasses RLS and sees every organization, so it cannot prove tenant isolation. That is what the pgTAP tests are for.
  - Connect only the dev project with demo data, **never production**.
  - Treat database content as untrusted input, because it can contain prompt injection.
  - Schema changes go only through migrations and `npx supabase db push`.

  ### 04 · Claude in CI

  When `build` or `db-tests` fails on a PR, the `analyze-failures` job gives Claude the logs (vitest, pgTAP, Edge Function tests), the JUnit report and the diff. Claude leaves one PR comment with the cause, a category and the smallest fix. It cannot push (`contents: read`), it can only read files and run `gh pr comment`, and a failure of the analysis never blocks the PR. It needs the `CLAUDE_CODE_OAUTH_TOKEN` secret.

  **Try it:** break a test and open a PR. A comment from `github-actions` should appear within 1–2 minutes. Example: PR #1.

  ### 05 · AI review of every PR

  On every non-draft PR from this repository, Claude reads the diff and checks it against the same rules as 01: RLS and tenant isolation, soft delete, migrations, status changes through the RPC, and real bugs. It posts one comment starting with `## AI review` and deletes its older review comments, so only the newest one stays. Read-only access to the code, advisory only, never blocks the PR. Fork PRs are skipped, because they get no secrets.

  **Try it:** open any PR. Example: PR #5.

  ### How the practices showed up in this work

  The Edge Function (PR #5) is an example of all five working together:

  - **01** — `rls-reviewer` reviewed the new outbox twice. The first pass found that any member could rewrite the vendor address through PostgREST and send an order elsewhere; the table became read-only for clients before the PR was merged. Earlier, it found the cross-organization references fixed in `0009`.
  - **02** — fixes to already applied migrations went into new files (`0009`–`0011`), never into `0006`–`0008`.
  - **03** — after the deploy, Claude used MCP to confirm on the dev project that `0010`/`0011` were applied and the seed users carry `org_id` in app_metadata.
  - **04** — the same `analyze-failures` job now also reads the pgTAP and Edge Function logs.
  - **05** — the AI review of PR #5 caught a migration comment that promised more than the code did; it was corrected before merge.

  The AI checks are advisory. What actually protects the data is in the database (RLS, RPCs, constraints) and is proven by the tests above.

  ## Status

  - The hook block has not been seen in a live session yet.
  - The dev project runs the Edge Function with `DRY_RUN=true` (no `RESEND_API_KEY` yet). Seed users have no password, so a real sign-in needs a password set in the Supabase dashboard first.
  - Known within-organization gaps (no cross-organization effect):
    - a member can call `record_purchase_order_email_attempt` from the browser and mark a queued email as sent without sending it (the Edge Function runs with the same JWT, so the database cannot tell them apart);
    - `purchase_orders` still allows a direct `update ... set status` through PostgREST, bypassing `transition_purchase_order` and the outbox (pre-existing, from `0007`);
    - two simultaneous retries of the same unsent email can send it twice.
