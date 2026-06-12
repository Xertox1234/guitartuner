#!/bin/bash
# PreToolUse hook — injects domain rules and solution refs before Edit/Write/MultiEdit.
# Per-session dedup: full rules on first edit in a domain, one-liner pointer on repeat.
# Output: JSON {"additionalContext": "..."} or silent exit 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=lib/domain-map.sh
source "$SCRIPT_DIR/lib/domain-map.sh"

domain_tag_pattern() {
  printf '\\b%s\\b' "$1"
}

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

SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")

# Resolve domains for this file
DOMAINS_RAW=$(get_domains "$FILE_PATH")
[[ -z "$DOMAINS_RAW" ]] && exit 0

# Sort domains by priority rank before processing
DOMAINS_SORTED=$(while IFS= read -r d; do
  [[ -z "$d" ]] && continue
  printf '%s\t%s\n' "$(domain_rank "$d")" "$d"
done <<< "$DOMAINS_RAW" | sort -n | cut -f2)

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

DEDUP=1
{ [ -z "$SESSION" ] || [ "${LUMA_PATTERN_INJECT_NO_DEDUP:-0}" = "1" ]; } && DEDUP=0
DEDUP_STATE="/tmp/luma-pattern-inject-${SESSION}"

while IFS= read -r domain; do
  [[ -z "$domain" ]] && continue

  RULES_FILE="$PROJECT_DIR/docs/rules/${domain}.md"

  # Per-session dedup
  if [ "$DEDUP" = "1" ] && grep -qxF "$domain" "$DEDUP_STATE" 2>/dev/null; then
    RULES_BODY="${RULES_BODY}
[${domain} rules already injected this session — see docs/rules/${domain}.md]"
    continue
  fi

  if [[ -f "$RULES_FILE" ]]; then
    RULES_BODY="${RULES_BODY}

--- ${domain} rules ---
$(cat "$RULES_FILE")"
    [ "$DEDUP" = "1" ] && printf '%s\n' "$domain" >> "$DEDUP_STATE"
  fi

  # Recent solution references for this domain (path + title only)
  SOLUTIONS_DIR="$PROJECT_DIR/docs/solutions"
  if [[ -d "$SOLUTIONS_DIR" ]]; then
    TAG_PATTERN=$(domain_tag_pattern "$domain")
    MATCHES=$(grep -rl --include='*.md' -E "^tags:.*${TAG_PATTERN}" \
      "$SOLUTIONS_DIR" 2>/dev/null \
      | grep -v '/README\.md' \
      | sed "s|.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)\.md\$|\1 &|" \
      | sort -r \
      | cut -d' ' -f2- \
      | head -n "$SOLUTIONS_PER_DOMAIN")

    if [ -n "$MATCHES" ]; then
      _FILE_REL="${FILE_PATH#$PROJECT_DIR/}"
      _NL=$'\n'
      _PRIORITY=""
      _FALLBACK=""
      while IFS= read -r _sol; do
        [ -n "$_sol" ] || continue
        _PATS=$(grep -m1 '^applies_to:' "$_sol" 2>/dev/null \
          | grep -oE '"[^"]+"' | tr -d '"' || true)
        _MATCHED=false
        if [ -n "$_PATS" ]; then
          while IFS= read -r _pat; do
            [ -n "$_pat" ] || continue
            # shellcheck disable=SC2254
            [[ "$_FILE_REL" == $_pat ]] && { _MATCHED=true; break; }
          done <<< "$_PATS"
        fi
        if [ "$_MATCHED" = true ]; then
          _PRIORITY="${_PRIORITY:+$_PRIORITY$_NL}$_sol"
        else
          _FALLBACK="${_FALLBACK:+$_FALLBACK$_NL}$_sol"
        fi
      done <<< "$MATCHES"
      MATCHES=$(printf '%s\n%s\n' "$_PRIORITY" "$_FALLBACK" \
        | grep -v '^$' | head -n "$SOLUTIONS_PER_DOMAIN")
    fi

    while IFS= read -r sol_file; do
      [[ -f "$sol_file" ]] || continue
      title=$(grep '^title:' "$sol_file" 2>/dev/null | head -1 | \
        sed 's/^title:[[:space:]]*//' | tr -d '"')
      rel="${sol_file#"$PROJECT_DIR/"}"
      SOLUTIONS_BODY="${SOLUTIONS_BODY}- ${rel}: ${title}
"
    done <<< "$MATCHES"
  fi
done <<< "$DOMAINS_SORTED"

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
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
printf '%s\n' "$CONTEXT" > "$TMPFILE"
CONTEXT_SIZE=$(wc -c < "$TMPFILE")
if [ "$CONTEXT_SIZE" -gt "$BYTE_CAP" ]; then
  OVERFLOW="/tmp/luma-injection-context.md"
  cp "$TMPFILE" "$OVERFLOW"
  head -c $((BYTE_CAP - 200)) "$TMPFILE" > "${TMPFILE}.trunc"
  mv "${TMPFILE}.trunc" "$TMPFILE"
  printf '\n\n[TRUNCATED — %d bytes total. Full context at %s]\n' \
    "$CONTEXT_SIZE" "$OVERFLOW" >> "$TMPFILE"
  CONTEXT=$(cat "$TMPFILE")
fi

jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
