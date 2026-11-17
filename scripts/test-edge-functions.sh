#!/usr/bin/env bash
# End-to-end tests of Edge Functions against the local Supabase stack.
# Needs a running stack with fresh seed data: `supabase start` or `supabase db reset`.
# Serves the functions with a mock email provider, runs the tests, stops serving.
set -euo pipefail
cd "$(dirname "$0")/.."

SUPABASE="${SUPABASE:-npx supabase@3.2.0}"
export MOCK_EMAIL_PORT="${MOCK_EMAIL_PORT:-54399}"

eval "$($SUPABASE status -o env | grep -E '^(API_URL|ANON_KEY|JWT_SECRET)=' | sed 's/^/export /')"

# Functions run in Docker; host.docker.internal reaches the mock on the host.
env_file="$(mktemp)"
cat > "$env_file" <<EOF
RESEND_API_KEY=test-key
RESEND_API_URL=http://host.docker.internal:${MOCK_EMAIL_PORT}/emails
EMAIL_FROM=test@purchasing-app.test
EOF

log="$(mktemp)"
serve_pid=
trap 'kill $serve_pid 2>/dev/null || true; rm -f "$env_file"' EXIT

# Right after `supabase db reset` the edge runtime container is still restarting
# and `functions serve` can exit with "must be a directory"; retry a few times.
for attempt in 1 2 3; do
  $SUPABASE functions serve --env-file "$env_file" > "$log" 2>&1 &
  serve_pid=$!
  for _ in $(seq 1 60); do
    grep -q 'Serving functions' "$log" && break
    kill -0 "$serve_pid" 2>/dev/null || break
    sleep 1
  done
  grep -q 'Serving functions' "$log" && break
  echo "functions serve did not start (attempt $attempt):"; cat "$log"
  kill "$serve_pid" 2>/dev/null || true
  sleep 5
done
grep -q 'Serving functions' "$log" || exit 1

status=0
node --test supabase/functions/*/e2e.mjs || status=$?
[ "$status" -eq 0 ] || { echo '--- functions serve log ---'; cat "$log"; }
exit "$status"
