#!/bin/bash
# Tests for scripts/lib/invariant-patterns.sh — pure deterministic checks.
# Run:  bash .claude/hooks/tests/invariant-patterns.test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT/scripts/lib/invariant-patterns.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0
mk() { local rel="$1"; shift; mkdir -p "$W/$(dirname "$rel")"; printf '%s\n' "$@" > "$W/$rel"; printf '%s' "$W/$rel"; }
expect()  { # expect <name> <file> <severity> <pattern>
  if inv_check_file "$2" | grep -qE "^$3:.*$4"; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (got: %s)\n' "$1" "$(inv_check_file "$2" | tr '\n' '|')"; fi
}
silent() { # silent <name> <file>
  if [ -z "$(inv_check_file "$2")" ]; then PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else FAIL=$((FAIL+1)); printf '  FAIL %s (got: %s)\n' "$1" "$(inv_check_file "$2" | tr '\n' '|')"; fi
}

# ATS
expect "ats flagged"   "$(mk App/Info.plist '<key>NSAllowsArbitraryLoads</key>' '<true/>')" HARD 'NSAllowsArbitraryLoads'
silent "ats clean"     "$(mk App/Clean.plist '<key>CFBundleName</key>' '<string>LUMA</string>')"

# appending(component:) — scoped
expect "append route bad"  "$(mk App/Networking/LumaAPI.swift 'let u = base.appending(component: "auth/apple")')" HARD 'appending'
silent "append fs ok"      "$(mk App/Tunings/TuningCardStore.swift 'self.cacheURL = support.appending(component: "luma.json")')"

# networking outside allow-list
expect "net leak"      "$(mk App/Views/SomeView.swift 'let s = URLSession.shared')" HARD 'networking'
silent "net allowed"   "$(mk App/Networking/LumaAPI.swift 'let s = URLSession.shared')"

# print / debugPrint (REVIEW)
expect "print flagged"     "$(mk App/Engine/LiveTunerModel.swift 'print("[LUMA] hi")')" HARD 'print'
expect "debugPrint flagged" "$(mk App/Engine/X.swift 'debugPrint(thing)')" HARD 'print'
silent "fingerprint ok"    "$(mk App/Engine/Y.swift 'let fingerprint(x) = 1')"
silent "print in tests ok" "$(mk App/EngineTests/Z.swift 'print("[LUMA] hi")')"

# Keychain (REVIEW) — substring trap
expect "keychain bad"  "$(mk App/Account/KeychainStore.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlock')" HARD 'Keychain'
silent "keychain good" "$(mk App/Account/Good.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly')"

# Test/benchmark files are excluded from enforcement — they reference forbidden
# patterns by design (e.g. LumaAPIURLTests asserts that appending(component:) is
# wrong for routes). A *LumaAPI*-named TEST matches the appending scope by name,
# so the test-file guard must win.
silent "append in LumaAPI test ok"  "$(mk LUMA/Tests/LumaAPIURLTests.swift 'let u = base.appending(component: "auth/apple")')"
silent "net in App test ok"         "$(mk App/Views/SomeViewTests.swift 'let s = URLSession.shared')"
silent "keychain in test ok"        "$(mk App/Account/KeychainStoreTests.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlock')"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
