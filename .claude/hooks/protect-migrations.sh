#!/usr/bin/env bash
# PreToolUse(Edit|Write): block changes to migrations that are already committed.
# A committed migration is treated as applied; changes go into a new migration.
# Exit 2 blocks the tool call; stderr is shown to Claude as the reason.

f="$(jq -r '.tool_input.file_path // empty')"
[ -n "$f" ] || exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0
rel="$(realpath -m --relative-to="$CLAUDE_PROJECT_DIR" "$f")"

case "$rel" in supabase/migrations/*.sql) ;; *) exit 0 ;; esac

if git ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
  echo "Blocked: $rel is already committed and treated as applied. Do not modify it — create a new migration with the next number (see the supabase-migration skill)." >&2
  exit 2
fi

exit 0
