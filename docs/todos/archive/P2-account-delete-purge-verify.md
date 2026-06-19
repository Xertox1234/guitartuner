---
priority: P2
status: open
domain: security
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (B-4)
---

# Verify account deletion purges Keychain tokens and cached account JSON

## Problem

`docs/rules/security.md` requires account deletion to purge Keychain tokens *and* cached account JSON. A deletion path is referenced in `App/Account/AccountModel.swift` and `App/Views/Monetization/BottomDrawer.swift`, but the completeness of the purge (Keychain + every cache file) is unverified.

## Fix

- Trace the deletion path; confirm it deletes every Keychain item written by `KeychainStore` and removes/empties `TuningCardStore` / `GearStoreModel` caches.
- Add a test asserting post-delete: Keychain read returns nil and cache files are absent/empty.

## Files

- `App/Account/AccountModel.swift`
- `App/Account/KeychainStore.swift`
- `App/Tunings/TuningCardStore.swift`, `App/Store/GearStoreModel.swift`

## Verification

New `LUMATests` case: write token + cache, invoke delete, assert both gone.
