#!/bin/bash
# PostToolUse hook — verifies a git commit actually landed after a git commit Bash call.
# Fires after all Bash calls; exits silently unless the command was a git commit.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

case "$COMMAND" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

STAGED=$(git -C "${CLAUDE_PROJECT_DIR:-.}" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
HEAD=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --short HEAD 2>/dev/null || echo "unknown")

if [[ "$STAGED" -gt 0 ]]; then
  jq -n --arg msg "WARNING: ${STAGED} staged file(s) still present after git commit — a hook may have blocked it. HEAD is still ${HEAD}. Investigate before proceeding." \
    '{"additionalContext": $msg}'
else
  jq -n --arg msg "Commit landed. HEAD: ${HEAD}" '{"additionalContext": $msg}'
fi
