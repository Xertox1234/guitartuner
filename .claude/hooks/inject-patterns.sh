#!/bin/bash
# PreToolUse hook — injects domain rules and solution refs before Edit/Write/MultiEdit.
# Per-session dedup: full rules on first edit in a domain, one-liner pointer on repeat.
# Output: JSON {"additionalContext": "..."} or silent exit 0.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib/domain-map.sh
source "$SCRIPT_DIR/lib/domain-map.sh"

# Read stdin once
INPUT=$(cat)

# Only fire on file-editing tools
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[[ -z "$FILE_PATH" ]] && exit 0

SESSION="${CLAUDE_SESSION_ID:-}"

# Resolve domains for this file
DOMAINS_RAW=$(get_domains "$FILE_PATH")
[[ -z "$DOMAINS_RAW" ]] && exit 0

# Preamble — always included
PREAMBLE="LUMA editing standards:
- Think before writing code. Understand the full intent before changing anything.
- Surgical: change only what the task requires. Don't refactor neighbours.
- TunerEngine must remain UI-free (no SwiftUI, no LumaDesignSystem imports).
- LumaDesignSystem must remain logic-free (no TunerEngine, no AVAudioEngine imports).
- Swift Concurrency: async/await + actors everywhere. No Combine.
- No force-unwrapping in production code paths.
- After edits: XcodeRefreshCodeIssuesInFile to catch type errors fast."

RULES_BODY=""
SOLUTIONS_BODY=""
SOLUTIONS_PER_DOMAIN=4
BYTE_CAP=9000

while IFS= read -r domain; do
  [[ -z "$domain" ]] && continue

  RULES_FILE="$PROJECT_DIR/docs/rules/${domain}.md"
  DEDUP_KEY="/tmp/luma-injected-${SESSION}-${domain}"

  # Per-session dedup
  if [[ -n "$SESSION" && -f "$DEDUP_KEY" && -z "${LUMA_PATTERN_INJECT_NO_DEDUP:-}" ]]; then
    RULES_BODY="${RULES_BODY}
[${domain} rules already injected this session — see docs/rules/${domain}.md]"
    continue
  fi

  if [[ -f "$RULES_FILE" ]]; then
    RULES_BODY="${RULES_BODY}

--- ${domain} rules ---
$(cat "$RULES_FILE")"
    if [[ -n "$SESSION" ]]; then
      touch "$DEDUP_KEY" 2>/dev/null || true
    fi
  fi

  # Recent solution references for this domain (path + title only)
  SOLUTIONS_DIR="$PROJECT_DIR/docs/solutions"
  if [[ -d "$SOLUTIONS_DIR" ]]; then
    count=0
    while IFS= read -r sol_file; do
      [[ "$count" -ge "$SOLUTIONS_PER_DOMAIN" ]] && break
      [[ -f "$sol_file" ]] || continue
      if grep -q "\b${domain}\b" "$sol_file" 2>/dev/null; then
        title=$(grep '^title:' "$sol_file" 2>/dev/null | head -1 | \
          sed 's/^title:[[:space:]]*//' | tr -d '"')
        rel="${sol_file#"$PROJECT_DIR/"}"
        SOLUTIONS_BODY="${SOLUTIONS_BODY}- ${rel}: ${title}
"
        count=$((count + 1))
      fi
    done < <(find "$SOLUTIONS_DIR" -name '*.md' ! -name 'README.md' 2>/dev/null | sort -r | head -40)
  fi
done <<< "$DOMAINS_RAW"

# Assemble
CONTEXT="$PREAMBLE"
[[ -n "$RULES_BODY" ]] && CONTEXT="${CONTEXT}
${RULES_BODY}"
if [[ -n "$SOLUTIONS_BODY" ]]; then
  CONTEXT="${CONTEXT}

Recent solutions:
${SOLUTIONS_BODY}"
fi

# Spill overflow to temp file if over byte cap
if [[ ${#CONTEXT} -gt $BYTE_CAP ]]; then
  OVERFLOW="/tmp/luma-injection-context.md"
  printf '%s\n' "$CONTEXT" > "$OVERFLOW"
  CONTEXT="${CONTEXT:0:$BYTE_CAP}
[...truncated — full context at $OVERFLOW]"
fi

jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
