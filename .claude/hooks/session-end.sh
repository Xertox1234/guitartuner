#!/bin/bash
# Stop hook — surfaces open TODOs at end of session and nudges codification.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

OPEN_FILES=$(grep -rl "TODO\|FIXME\|HACK" \
  "$PROJECT_DIR/LUMA" \
  "$PROJECT_DIR/Packages" \
  --include="*.swift" 2>/dev/null | head -10 || true)

if [[ -n "$OPEN_FILES" ]]; then
  MSG="Open TODOs/FIXMEs found in:
${OPEN_FILES}

If this session produced non-obvious patterns, constraints, or bug root causes — run /codify."
else
  MSG="No open TODOs found. If this session produced non-obvious patterns worth preserving, run /codify."
fi

jq -n --arg msg "$MSG" '{"additionalContext": $msg}'
