---
priority: P1
status: open
domain: security
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (B-1)
---

# Switch Keychain token accessibility to ...ThisDeviceOnly, then promote the gate

## Problem

`App/Account/KeychainStore.swift` writes with `kSecAttrAccessibleAfterFirstUnlock`, which is eligible to migrate to a new device via encrypted backup restore. Bearer credentials should not leave the device. `…ThisDeviceOnly` keeps background refresh while blocking backup migration.

## Fix

- Change `kSecAttrAccessibleAfterFirstUnlock` → `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` in `KeychainStore.write`.
- In `scripts/lib/invariant-patterns.sh`, promote `inv_check_keychain` from `REVIEW:` to `HARD:`; confirm the negative pattern (`AfterFirstUnlock` not followed by `ThisDeviceOnly`) does NOT flag the new correct form, and `./scripts/ci-invariants.sh` exits 0.

## Files

- `App/Account/KeychainStore.swift:19`
- `scripts/lib/invariant-patterns.sh` (`inv_check_keychain`)

## Verification

Sign-in round-trip still works after relaunch; `./scripts/ci-invariants.sh` → 0 HARD; the Keychain check fires on a fixture using the bare `AfterFirstUnlock` form and stays silent on `…ThisDeviceOnly`.
