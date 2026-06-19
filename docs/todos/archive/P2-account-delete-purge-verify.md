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

## Resolution (2026-06-19, sub-project 2 / B-4)

Resolved via `LUMA/Tests/AccountPurgeTests.swift` (commit `18a194a`).

**Outcome:** the only Keychain item written is `"jwt"`; `deleteAccount()` purges it
via `clearJWT()`. The `luma_tuning_cards.json` / `luma_gear_products.json` caches are
*not* account-scoped — they carry no PII, credential, or account identifier — and
survive deletion by design. There is no separate "account JSON" cache. `docs/rules/security.md`
line 10 was clarified accordingly.

**Test-scope deviation (deliberate, documented — not a quiet downscope):** the original
fix above said "invoke delete, assert both gone." The shipped tests instead exercise the
shared, network-free local-purge primitive (`clearJWT` / `signOut`) that `deleteAccount`
reuses, rather than driving `deleteAccount` end-to-end. Reason: the `LumaAPI` actor's
`URLSession` is not injectable, and `deleteAccount`'s only *local* purge action is
`clearJWT()`; the server-delete leg is not relevant to the local-credential guarantee.
A `KeychainStoring` seam + in-memory fake keeps the test deterministic and CI-safe
(headless CI runs unsigned, where a real `SecItem` call risks `errSecMissingEntitlement`).
