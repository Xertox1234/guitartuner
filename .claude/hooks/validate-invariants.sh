#!/bin/bash
# PostToolUse hook — validates mechanizable LUMA invariants after Edit/Write/MultiEdit.
#
# Companion to inject-patterns.sh: that hook *informs* before an edit; this one
# *verifies* after. Turns the highest-value, grep-able rules from advisory into
# enforced.
#
#   HARD violations  (package boundaries, forbidden imports)  -> stderr + exit 2
#   REVIEW items     (force ops, networking creep — heuristic) -> additionalContext, exit 0
#   clean file                                                 -> silent exit 0
#
# Two channels, split by confidence:
#   * HARD violations are deterministic. Exit 2 sends stderr back to Claude
#     (PostToolUse contract); the edit already applied, so it's a "now fix it"
#     signal, not a block.
#   * REVIEW items are heuristic and scan the whole file, so they can flag
#     pre-existing lines on an unrelated edit. They're surfaced via non-blocking
#     additionalContext on exit 0 — informs without nagging on every edit.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/lib/invariant-patterns.sh
source "$PROJECT_DIR/scripts/lib/invariant-patterns.sh"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[[ -z "$FILE_PATH" ]] && exit 0
case "$FILE_PATH" in *.swift|*.plist) ;; *) exit 0 ;; esac
[[ -f "$FILE_PATH" ]] || exit 0

# --- Classify by package / layer (path-based — robust regardless of repo layout) ---
is_tunerengine=false; is_designsystem=false; is_app=false
case "$FILE_PATH" in
  */Packages/TunerEngine/*)      is_tunerengine=true ;;
  */Packages/LumaDesignSystem/*) is_designsystem=true ;;
  */App/*)                       is_app=true ;;
esac

# Tests and benchmarks are not "production code paths"
is_production=true
case "$FILE_PATH" in
  *Tests/*|*Test.swift|*Tests.swift|*/Bench/*|*Benchmark*) is_production=false ;;
esac


VIOLATIONS=""
REVIEW=""
add_violation() { VIOLATIONS="${VIOLATIONS}  ✗ $1"$'\n'; }
add_review()    { REVIEW="${REVIEW}  • $1"$'\n'; }

# Shared deterministic security invariants (single source of truth — also run in CI).
while IFS= read -r _inv; do
  [ -n "$_inv" ] || continue
  case "$_inv" in
    HARD:*)   add_violation "${_inv#HARD:}" ;;
    REVIEW:*) add_review    "${_inv#REVIEW:}" ;;
  esac
done < <(inv_check_file "$FILE_PATH")

# Report the first line matching a forbidden `import <module>`.
# Covers `import Mod`, `@_exported import Mod`, the symbol form
# `import struct Mod.Symbol`, and submodule imports `import Mod.Sub`
# (the `.` in the trailing boundary catches the dotted forms).
check_forbidden_import() {
  local mod="$1" why="$2" hit
  hit=$(grep -nE "^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)?import[[:space:]]+((class|struct|enum|protocol|func|var|let|typealias)[[:space:]]+)?${mod}([[:space:]]|;|\.|$)" \
        "$FILE_PATH" 2>/dev/null | head -1)
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: forbidden 'import ${mod}' — ${why}"
}

first_match() { grep -nE "$1" "$FILE_PATH" 2>/dev/null | head -1; }

# Like first_match, but blanks // line comments first (best-effort) so a bare
# identifier mentioned in a comment doesn't trip a HARD violation. Block comments
# and string literals are NOT stripped — a rare edge for these identifiers.
first_match_code() { sed 's://.*$::' "$FILE_PATH" 2>/dev/null | grep -nE "$1" 2>/dev/null | head -1; }

# --- Project-wide: no Combine (Swift Concurrency everywhere) ---
check_forbidden_import Combine "no Combine in LUMA — use async/await + AsyncStream"

# --- TunerEngine: UI-free, logic-only, no networking (audio never leaves device) ---
if $is_tunerengine; then
  check_forbidden_import SwiftUI          "TunerEngine must remain UI-free"
  check_forbidden_import LumaDesignSystem "TunerEngine must not depend on the design system"
  check_forbidden_import Network          "no networking in the engine — audio must never leave the device"
  hit=$(first_match_code '\bURLSession\b')
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: URLSession in TunerEngine — the engine must have no networking"
fi

# --- LumaDesignSystem: logic-free, no DSP, no audio, no networking ---
if $is_designsystem; then
  check_forbidden_import TunerEngine  "LumaDesignSystem must stay logic-free (no DSP dependency)"
  check_forbidden_import AVFoundation "LumaDesignSystem must not touch audio/capture"
  hit=$(first_match_code '\bURLSession\b')
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: URLSession in LumaDesignSystem — the design system must have no networking"
fi


# --- Force operations in production code (heuristic; high-signal subset only) ---
# try!/as! are reliable to spot. Generic optional force-unwrap (foo!) is NOT done
# here — too noisy in bash (strings/comments). See follow-up: swiftlint force_* rules.
if $is_production; then
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    add_review "line ${line%%:*}: force operation (try!/as!) — avoid in production paths or justify it"
  done < <(grep -nE '\b(try|as)!' "$FILE_PATH" 2>/dev/null | head -8)
fi

# --- Report (two channels, split by confidence) ---
REL="${FILE_PATH#"$PROJECT_DIR/"}"

# HARD violations block the flow: stderr + exit 2 feeds back to the model.
# Any REVIEW items ride along in the same report (we're already interrupting).
if [ -n "$VIOLATIONS" ]; then
  {
    echo "LUMA invariant check — ${REL}"
    echo
    echo "VIOLATIONS (architecture/quality rules — fix before continuing):"
    printf '%s' "$VIOLATIONS"
    if [ -n "$REVIEW" ]; then
      echo
      echo "REVIEW (heuristic — confirm each is intentional, otherwise fix):"
      printf '%s' "$REVIEW"
    fi
  } >&2
  exit 2
fi

# REVIEW-only: non-blocking. Heuristic items (and whole-file rescans of pre-existing
# lines) shouldn't nag on every edit, so surface them via additionalContext on exit 0.
if [ -n "$REVIEW" ]; then
  MSG="LUMA invariant check — ${REL}

REVIEW (heuristic — confirm each is intentional, otherwise fix):
${REVIEW}"
  jq -n --arg ctx "$MSG" \
    '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
fi

exit 0
