# Security rules

Cross-cutting domain — co-injected alongside the architectural domain when editing
networking, account, persistence, capture-permission, or privacy-surface files.

- **Audio privacy is architectural.** `TunerEngine` has no networking; audio is never recorded, stored, or transmitted. Enforced by package boundaries, not convention.
- **All backend networking lives in `LumaAPI` only.** HTTPS-only — never add an ATS exception (`NSAllowsArbitraryLoads`). The opt-in account/monetization stack (`LumaAPI`, `AccountModel`, `TuningCardStore`, `GearStoreModel`, `LumaApp`) is the only place `URLSession` belongs.
- **API route construction** goes through `LumaAPI.buildURL` / `appending(path:)`, never `appending(component:)` — it percent-encodes slashes and silently breaks multi-segment routes (`auth/apple` → `auth%2Fapple`). Scope: route strings only; `appending(component:)` is correct for a single-segment *filesystem* name (the cache stores' `…json` files). See `docs/solutions/logic-errors/url-appending-component-encodes-slashes-2026-06-15.md`.
- **Tokens and secrets live in the Keychain**, never `UserDefaults` or a JSON cache. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — preserves background token refresh while keeping the credential off encrypted backups (no device-migration leak).
- **Account data minimization.** Only the user's email is collected, opt-in, and declared in `App/PrivacyInfo.xcprivacy`. Account deletion must purge Keychain tokens *and* any cached account JSON (as of 2026-06-19 there is no separate account-JSON cache — account state derives from the Keychain token; the `luma_tuning_cards.json` / `luma_gear_products.json` caches are not account-scoped and survive deletion by design). Scope privacy claims precisely: "audio never leaves the device; no account is required to tune; the optional account collects only email."
- **Logging.** Use `os.Logger` with `.private` qualifiers in `App/`. Never `print`/`debugPrint` PII, secrets, or raw error objects on a network or auth path — `print` is unredacted stderr.
- **Never `assertionFailure`/`fatalError`/`precondition` on a recoverable path** (cache write, network response, external-data decode). Log and degrade to stale/empty data. See `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`.
- **Keep `PrivacyInfo.xcprivacy` accurate.** Declare any newly collected data type or required-reason API.
- **macOS audio entitlement.** Sandboxed/notarized macOS builds need `com.apple.security.device.audio-input`. See `docs/solutions/macos-audio-input-entitlement-2026-06-12.md`.
