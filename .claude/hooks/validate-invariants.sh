#!/bin/bash
# PostToolUse hook — validates mechanizable LUMA invariants after Edit/Write/MultiEdit.
#
# Companion to inject-patterns.sh: that hook *informs* before an edit; this one
# *verifies* after. Turns the highest-value, grep-able rules from advisory into
# enforced.
#
#   HARD violations  (package boundaries, forbidden imports)  -> reported + exit 2
#   REVIEW items     (force ops, networking creep — heuristic) -> reported + exit 2
#   clean file                                                 -> silent exit 0
#
# Exit 2 sends stderr back to Claude (PostToolUse contract); the edit already
# applied, so this is a "now fix it" signal, not a block.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

INPUT=$(cat)

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != *.swift ]] && exit 0
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

# Files where backend networking is intentional (the opt-in monetization stack).
networking_allowed() {
  case "$1" in
    */App/Networking/*|*LumaAPI*|*AccountModel*|*TuningCardStore*|*GearStore*|*/App/LumaApp.swift) return 0 ;;
    *) return 1 ;;
  esac
}

VIOLATIONS=""
REVIEW=""
add_violation() { VIOLATIONS="${VIOLATIONS}  ✗ $1"$'\n'; }
add_review()    { REVIEW="${REVIEW}  • $1"$'\n'; }

# Report the first line matching a forbidden `import <module>`.
check_forbidden_import() {
  local mod="$1" why="$2" hit
  hit=$(grep -nE "^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)?import[[:space:]]+${mod}([[:space:]]|;|$)" \
        "$FILE_PATH" 2>/dev/null | head -1)
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: forbidden 'import ${mod}' — ${why}"
}

first_match() { grep -nE "$1" "$FILE_PATH" 2>/dev/null | head -1; }

# --- Project-wide: no Combine (Swift Concurrency everywhere) ---
check_forbidden_import Combine "no Combine in LUMA — use async/await + AsyncStream"

# --- TunerEngine: UI-free, logic-only, no networking (audio never leaves device) ---
if $is_tunerengine; then
  check_forbidden_import SwiftUI          "TunerEngine must remain UI-free"
  check_forbidden_import LumaDesignSystem "TunerEngine must not depend on the design system"
  check_forbidden_import Network          "no networking in the engine — audio must never leave the device"
  hit=$(first_match '\bURLSession\b')
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: URLSession in TunerEngine — the engine must have no networking"
fi

# --- LumaDesignSystem: logic-free, no DSP, no audio, no networking ---
if $is_designsystem; then
  check_forbidden_import TunerEngine  "LumaDesignSystem must stay logic-free (no DSP dependency)"
  check_forbidden_import AVFoundation "LumaDesignSystem must not touch audio/capture"
  hit=$(first_match '\bURLSession\b')
  [ -n "$hit" ] && add_violation "line ${hit%%:*}: URLSession in LumaDesignSystem — the design system must have no networking"
fi

# --- App layer: flag networking that has escaped the LumaAPI layer (soft) ---
if $is_app && ! networking_allowed "$FILE_PATH"; then
  hit=$(first_match '\b(URLSession|URLRequest)\b|^[[:space:]]*import[[:space:]]+Network\b')
  [ -n "$hit" ] && add_review "line ${hit%%:*}: networking outside the LumaAPI layer — confirm it belongs in App/Networking, not a view/model"
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

# --- Report ---
if [ -n "$VIOLATIONS" ] || [ -n "$REVIEW" ]; then
  REL="${FILE_PATH#"$PROJECT_DIR/"}"
  {
    echo "LUMA invariant check — ${REL}"
    if [ -n "$VIOLATIONS" ]; then
      echo
      echo "VIOLATIONS (architecture/quality rules — fix before continuing):"
      printf '%s' "$VIOLATIONS"
    fi
    if [ -n "$REVIEW" ]; then
      echo
      echo "REVIEW (heuristic — confirm each is intentional, otherwise fix):"
      printf '%s' "$REVIEW"
    fi
  } >&2
  exit 2
fi

exit 0
