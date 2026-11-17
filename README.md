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

  ## Status

  - MCP lives only on the `feat/supabase-mcp` branch, and its PR is not open yet.
  - The hook block has not been seen in a live session yet.
  - Until a Custom Access Token Hook exists, `current_org_id()` returns `null` and a signed-in user sees no rows.

