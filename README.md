 # purchasing-app

  A multi-tenant purchase-order module.
  **Stack:** React + TanStack React Query, Supabase (Postgres, RLS, RPC, Realtime).

  ## How we work with Claude Code

  The repository has four practices set up. Each one works automatically as soon as you open Claude Code in the project root.

  | # | Practice | What it gives you | Where it lives |
  |---|---|---|---|
  | 01 | Rules files | Claude knows the project rules without being reminded | `CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, `.claude/agents/` |
  | 02 | Hooks | Applied migrations cannot be edited | `.claude/settings.json`, `.claude/hooks/protect-migrations.sh` |
  | 03 | MCP | Claude reads the live dev schema and data instead of guessing | `.mcp.json` |
  | 04 | Claude in CI | The cause of a test failure arrives as a PR comment | `.github/workflows/ci.yml` |

  ### 01 · Rules files

  - `CLAUDE.md` always loads. It gives a short stack overview and 5 critical rules: tenant only from the JWT, soft delete, status changes via RPC, never edit migrations.
  - `.claude/rules/multi-tenancy.md` also always loads: every new table has `organization_id`, `deleted_at` and RLS, and the service role key is banned from `src/`.
  - `.claude/rules/frontend-data.md` loads only for `src/**/*.{ts,tsx}`. Supabase is called only from `api.ts`, and query keys come from a key factory.
  - Claude loads the `supabase-migration` skill when a task touches the schema.
  - The read-only `rls-reviewer` subagent checks organization isolation after every schema change.

  **Try it:** ask "add a warehouses table". Claude should create the next numbered migration with RLS and then run `rls-reviewer`.

  ### 02 · Hooks

  Before every `Edit`/`Write`, Claude Code runs `protect-migrations.sh`. If a file in `supabase/migrations/*.sql` is already in git, the edit is blocked (exit 2) and Claude creates a new migration instead. Migrations that are
  not committed yet can be edited freely.

  **Try it:** ask "add a currency column to 0007_purchase_orders.sql". Expect `Blocked: … is already committed` and a new `0009_…sql` file.

  ### 03 · MCP (Supabase, read-only)

  The official hosted Supabase MCP server is connected to the **dev project** with `read_only=true` and only the tool groups we need. Authentication is OAuth, so the repository holds no tokens.

  **First run:** open Claude Code, approve the `supabase` server, then run `/mcp` → `supabase` → sign in through the browser.

  **Limitations:**
  - MCP bypasses RLS and sees every organization, so it cannot prove tenant isolation.
  - Connect only the dev project with demo data, **never production**.
  - Treat database content as untrusted input, because it can contain prompt injection.
  - Schema changes go only through migrations and `npx supabase db push`.

  ### 04 · Claude in CI

  When tests fail on a PR, the `analyze-failures` job gives Claude the log, the JUnit report and the diff. Claude leaves one PR comment with the cause, a category and the smallest fix. It cannot push (`contents: read`), it can
  only read files and run `gh pr comment`, and a failure of the analysis never blocks the PR. It needs the `CLAUDE_CODE_OAUTH_TOKEN` secret.

  **Try it:** break a test and open a PR. A comment from `github-actions` should appear within 1–2 minutes. Example: PR #1.

  ## Edge Function: submit-purchase-order

  `POST /functions/v1/submit-purchase-order` with `{ "orderId": "..." }` sends an order to its vendor. The UI calls it from the "Submit to vendor" / "Retry email" button.

  1. `submit_purchase_order` RPC: moves the order to SUBMITTED through `transition_purchase_order` and queues one row in `purchase_order_emails`, in one transaction. Vendor without email or order without lines → 422, nothing changes.
  2. The function sends the email (Resend) and records the attempt. If the provider fails: 502, the order stays SUBMITTED, the email stays unsent with its error; calling the function again retries it. A sent email is final (409).
  3. Runs with the caller's JWT and the anon key, so RLS applies: another organization's order → 404.

  Secrets on the Supabase project: `RESEND_API_KEY`, optional `EMAIL_FROM`. `DRY_RUN=true` sends nothing and returns the email in the response (dev only). Without a key and without `DRY_RUN` every attempt fails with 502 and stays retryable.

  The outbox is read-only for clients: only `submit_purchase_order` and `record_purchase_order_email_attempt` write it, and `transition_purchase_order` refuses SUBMITTED without a queued email.

  **Tests:** `supabase test db` (pgTAP, incl. `005_purchase_order_emails.sql`), then `./scripts/test-edge-functions.sh` (end-to-end, mock email provider, needs fresh seed data). Both run in CI in the `db-tests` job.

  ## Status

  - The hook block has not been seen in a live session yet.
  - Known within-organization gaps (no cross-organization effect): a member can call `record_purchase_order_email_attempt` from the browser and mark a queued email as sent without sending it (the Edge Function runs with the same JWT, so the database cannot tell them apart); `purchase_orders` still allows a direct `update ... set status` through PostgREST, bypassing `transition_purchase_order` and the outbox (pre-existing, from 0007).
  - The tenant is `app_metadata.org_id` (migration `0010`), so real sign-ins see their organization without a Custom Access Token Hook. A new user needs `org_id` in app_metadata, set by an admin or the service role.

