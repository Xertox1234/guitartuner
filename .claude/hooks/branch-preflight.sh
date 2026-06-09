#!/bin/bash
# PreToolUse hook — blocks commits on a detached HEAD (silent data loss prevention).
# Only active when the Bash tool runs a git commit command.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

[[ -n "${SKIP_BRANCH_PREFLIGHT:-}" ]] && exit 0

HEAD_REF=$(git -C "${CLAUDE_PROJECT_DIR:-.}" symbolic-ref HEAD 2>/dev/null || true)
if [[ -z "$HEAD_REF" ]]; then
  printf '{"decision":"block","reason":"Refusing to commit on a detached HEAD — check out a branch first: git switch -c <name>"}'
  exit 0
fi

exit 0
