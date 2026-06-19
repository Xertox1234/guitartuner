#!/bin/bash
# Single source of truth for LUMA's deterministic SECURITY invariants.
# Sourced by .claude/hooks/validate-invariants.sh (per-file) and
# scripts/ci-invariants.sh (repo-wide). Each check takes ONE absolute path and
# echoes zero+ lines prefixed "HARD:" (blocks) or "REVIEW:" (advisory).
# Functions are pure and self-gate on file type/location.
#
# Scope note: this library is the SSOT for the SECURITY invariants only.
# validate-invariants.sh ALSO runs package-boundary checks (Combine ban,
# TunerEngine/LumaDesignSystem import bans, force-op heuristic) that are
# local-hook-only and NOT mirrored in CI — they are compile-enforced by the
# Swift build. Do not assume CI gates everything the hook flags.
#
# Test/benchmark files are excluded from enforcement: they reference forbidden
# patterns by design (e.g. LumaAPIURLTests asserts appending(component:) is wrong
# for routes; a KeychainStore test names the bare accessibility constant).

inv_networking_allowed() {
  case "$1" in
    */App/Networking/*|*LumaAPI*|*AccountModel*|*TuningCardStore*|*GearStoreModel*|*/App/LumaApp.swift) return 0 ;;
    *) return 1 ;;
  esac
}

# True for test/benchmark files — these are excluded from every invariant check.
inv_is_test_file() {
  case "$1" in *Tests/*|*Test.swift|*Tests.swift|*/Bench/*|*Benchmark*) return 0 ;; esac
  return 1
}

inv_is_app_production_swift() {
  case "$1" in *.swift) ;; *) return 1 ;; esac
  case "$1" in */App/*) ;; *) return 1 ;; esac
  inv_is_test_file "$1" && return 1
  return 0
}

# Blank // line comments so identifiers in comments don't trip checks (line count preserved).
inv_code_lines() { sed 's://.*$::' "$1" 2>/dev/null; }

# HARD: ATS exception in any plist
inv_check_ats() {
  case "$1" in *.plist) ;; *) return 0 ;; esac
  local hit; hit=$(grep -nE 'NSAllowsArbitraryLoads' "$1" 2>/dev/null | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: NSAllowsArbitraryLoads — no ATS exceptions; LumaAPI is HTTPS-only (docs/rules/security.md)"
}

# HARD: appending(component:) in API route construction (scoped to Networking/LumaAPI)
inv_check_appending_component() {
  case "$1" in *.swift) ;; *) return 0 ;; esac
  inv_is_test_file "$1" && return 0
  case "$1" in */App/Networking/*|*LumaAPI*) ;; *) return 0 ;; esac
  local hit; hit=$(inv_code_lines "$1" | grep -nE 'appending\(component:' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: appending(component:) percent-encodes slashes — use buildURL/appending(path:) for routes (docs/rules/security.md)"
}

# HARD: networking outside the LumaAPI allow-list
inv_check_networking_scope() {
  case "$1" in *.swift) ;; *) return 0 ;; esac
  inv_is_test_file "$1" && return 0
  case "$1" in */App/*) ;; *) return 0 ;; esac
  inv_networking_allowed "$1" && return 0
  local hit; hit=$(inv_code_lines "$1" | grep -nE '\b(URLSession|URLRequest)\b|^[[:space:]]*import[[:space:]]+Network\b' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: networking outside the LumaAPI layer — all backend calls go through LumaAPI (docs/rules/security.md)"
}

# HARD: print/debugPrint in App production code (use os.Logger with .private)
inv_check_print_in_app() {
  inv_is_app_production_swift "$1" || return 0
  local hit; hit=$(inv_code_lines "$1" | grep -nE '\b(print|debugPrint)\(' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: print/debugPrint in App/ — use os.Logger with .private for PII/secret paths (docs/rules/security.md)"
}

# HARD: Keychain AfterFirstUnlock without ThisDeviceOnly (substring-trap safe)
inv_check_keychain() {
  case "$1" in *.swift) ;; *) return 0 ;; esac
  inv_is_test_file "$1" && return 0
  local hit; hit=$(inv_code_lines "$1" | grep -nE 'kSecAttrAccessibleAfterFirstUnlock' | grep -vE 'ThisDeviceOnly' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: Keychain AfterFirstUnlock without ThisDeviceOnly — backup-restore-eligible; prefer …AfterFirstUnlockThisDeviceOnly (docs/rules/security.md)"
}

# Run every check against one file.
inv_check_file() {
  inv_check_ats "$1"
  inv_check_appending_component "$1"
  inv_check_networking_scope "$1"
  inv_check_print_in_app "$1"
  inv_check_keychain "$1"
  true  # always exit 0 so pipelines under set -o pipefail don't misfire
}
