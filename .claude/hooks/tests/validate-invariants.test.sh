#!/bin/bash
# Tests for validate-invariants.sh — the PostToolUse LUMA invariant checker.
#
# Self-contained: builds temp .swift fixtures, pipes synthetic PostToolUse JSON
# payloads into the hook, and asserts the exit code + which feedback channel fired:
#   * HARD violations -> stderr + exit 2
#   * REVIEW items    -> stdout additionalContext (JSON) + exit 0
#   * clean / skipped -> silent exit 0
#
# Run:  bash .claude/hooks/tests/validate-invariants.test.sh
# Exit: 0 if all pass, 1 otherwise.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HOOK_DIR/validate-invariants.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
no() { FAIL=$((FAIL + 1)); printf '  FAIL %s\n         %s\n' "$1" "$2"; }

# make_file <relpath> <line...>  -> echoes the absolute path it wrote
make_file() {
  local rel="$1"; shift
  local abs="$WORK/$rel"
  mkdir -p "$(dirname "$abs")"
  printf '%s\n' "$@" > "$abs"
  printf '%s' "$abs"
}

# payload <tool_name> <file_path>  -> JSON on stdout
payload() {
  jq -n --arg t "$1" --arg f "$2" \
    '{"tool_name":$t,"tool_input":{"file_path":$f}}'
}

# run_case <name> <tool> <file> <want_exit> <none|stderr|stdout> [grep_pattern]
run_case() {
  local name="$1" tool="$2" file="$3" want_exit="$4" want_chan="$5" pat="${6:-}"
  local out code err
  out="$(payload "$tool" "$file" | bash "$HOOK" 2>"$WORK/.err")"; code=$?
  err="$(cat "$WORK/.err")"

  if [ "$code" != "$want_exit" ]; then
    no "$name" "expected exit $want_exit, got $code (stderr: ${err:-<empty>})"; return
  fi
  case "$want_chan" in
    none)
      { [ -n "$out" ] || [ -n "$err" ]; } &&
        { no "$name" "expected silence, got out='$out' err='$err'"; return; } ;;
    stderr)
      [ -z "$err" ] && { no "$name" "expected stderr output, got none"; return; }
      [ -n "$out" ] && { no "$name" "expected NO stdout, got '$out'"; return; }
      [ -n "$pat" ] && ! grep -qE "$pat" <<<"$err" &&
        { no "$name" "stderr missing /$pat/: $err"; return; } ;;
    stdout)
      [ -z "$out" ] && { no "$name" "expected stdout output, got none"; return; }
      grep -q '"additionalContext"' <<<"$out" ||
        { no "$name" "stdout missing additionalContext JSON: $out"; return; }
      [ -n "$err" ] && { no "$name" "expected NO stderr, got '$err'"; return; }
      [ -n "$pat" ] && ! grep -qE "$pat" <<<"$out" &&
        { no "$name" "stdout missing /$pat/: $out"; return; } ;;
  esac
  ok "$name"
}

printf 'validate-invariants.sh\n'

# --- Core smoke cases (the original four) ---
f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Foo.swift" "import SwiftUI" "struct Foo {}")
run_case "HARD: SwiftUI import in TunerEngine -> exit 2 / stderr" Write "$f" 2 stderr "VIOLATIONS"

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Clean.swift" "import Foundation" "let x = 1")
run_case "clean: plain Foundation file is silent" Write "$f" 0 none

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/notes.txt" "import SwiftUI")
run_case "skip: non-swift file" Write "$f" 0 none

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Bar.swift" "import SwiftUI")
run_case "skip: non-edit tool (Bash)" Bash "$f" 0 none

# --- finding 1: HARD vs REVIEW channel split ---
f=$(make_file "App/Engine/Thing.swift" "let d = try! make()")
run_case "REVIEW-only: try! in App -> exit 0 / additionalContext" Write "$f" 0 stdout "force operation"

# HARD + REVIEW together: violation blocks (exit 2) and the review rides along on stderr.
f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Both.swift" "import SwiftUI" "let d = try! make()")
run_case "HARD+REVIEW: review rides along in the exit-2 stderr report" Write "$f" 2 stderr "REVIEW"

# --- finding 2: submodule / symbol imports are caught ---
f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Sym.swift" "import struct SwiftUI.Color")
run_case "finding2: 'import struct SwiftUI.Color' caught" Write "$f" 2 stderr "import SwiftUI"

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Sub.swift" "import Combine.Publisher")
run_case "finding2: dotted submodule 'import Combine.Publisher' caught" Write "$f" 2 stderr "import Combine"

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Near.swift" "import SwiftUIKit")
run_case "finding2: lookalike 'import SwiftUIKit' NOT flagged" Write "$f" 0 none

# --- finding 3: bare identifier in a // comment is not a false positive ---
f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Cmt.swift" "// no URLSession here, just a note" "let x = 1")
run_case "finding3: URLSession in // comment is clean" Write "$f" 0 none

f=$(make_file "Packages/TunerEngine/Sources/TunerEngine/Net.swift" "let s = URLSession.shared")
run_case "finding3: real URLSession in engine still flagged" Write "$f" 2 stderr "URLSession"

# --- finding 4: GearStore whitelist tightened to GearStoreModel ---
f=$(make_file "App/GearStoreModel.swift" "let s = URLSession.shared")
run_case "finding4: URLSession in GearStoreModel is permitted" Write "$f" 0 none

f=$(make_file "App/GearStoreScreen.swift" "let s = URLSession.shared")
run_case "finding4: URLSession in GearStoreScreen (view) is flagged" Write "$f" 0 stdout "networking outside"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
