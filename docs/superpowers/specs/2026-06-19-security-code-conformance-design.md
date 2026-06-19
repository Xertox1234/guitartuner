# Sub-project 2 — Security Code Conformance + Gate Promotion (Design)

**Date:** 2026-06-19
**Status:** approved — ready for implementation plan
**Source:** `docs/audits/2026-06-18-patterns-vs-best-practices.md` (A-1, B-1, B-4)
**Predecessor:** sub-project 1 (governance) — PR #50, merged `d2572b0`. That work
*codified* the rules and stood up the REVIEW/HARD invariant machinery; this
sub-project makes the App code conform and promotes the two deferred gates.

## Goal

Make `App/` conform to the three security rules that `docs/rules/security.md`
**already mandates** (lines 9–11), then promote the two deferred REVIEW invariant
gates to HARD so the conformance is enforced going forward.

- **No rule changes** — `security.md` already requires all three behaviours.
- **No networking-logic changes** — the `LumaAPI` actor's request/refresh logic
  is untouched; B-4 adds only an injection seam on the keychain dependency.

## Background — what's already true

`security.md` lines 9–11 mandate:
- Tokens in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Account deletion purges Keychain tokens (and any cached account JSON).
- `os.Logger` with `.private` in `App/`; never `print`/`debugPrint` of PII,
  secrets, or raw error objects on a network/auth path.

The code has not yet caught up:
- `KeychainStore.swift:19` writes `kSecAttrAccessibleAfterFirstUnlock` (no
  `…ThisDeviceOnly`).
- Six `print("[LUMA] …")` sites across four `App/` files; three interpolate raw
  `\(error)` (`TuningCardStore.swift:74`, `AccountSheet.swift:208` on the auth
  path, `GearStoreModel.swift:57`).
- Account deletion's purge completeness is unverified by any test.

The two deterministic gates for print and Keychain currently emit `REVIEW:`
(advisory). Current scan baseline: **0 HARD / 5 REVIEW** — the 5 are exactly the
4 print files + 1 keychain file this sub-project cleans.

## Acceptance gate

After the code fixes (before promotion): `./scripts/ci-invariants.sh` →
**0 HARD / 0 REVIEW**. Promotion then lands on already-clean code, so every
intermediate commit stays green. If the scan is not 0/0 after the fixes,
something leaked (e.g. a missed print site) — that is the stop condition.

## Scope — three work items

### A-1 — `os.Logger` migration

Replace **all six** `print("[LUMA] …")` sites (not just the first per file — the
scanner reports first-hit-per-file, so a partial migration leaves the gate
firing):

| File | Line(s) | Note |
|------|---------|------|
| `App/Tunings/TuningCard.swift` | 27 | literal message |
| `App/Tunings/TuningCardStore.swift` | 74 | interpolates `\(error)` |
| `App/Views/Monetization/AccountSheet.swift` | 199, 205, 208 | 208 interpolates `\(error)` on the auth path |
| `App/Store/GearStoreModel.swift` | 57 | interpolates `\(error)` |

Design:
- **Per-file logger**, matching the lone in-repo precedent
  (`Packages/LumaDesignSystem/.../Fonts/LumaFonts.swift` declares its own
  `private static let logger = Logger(subsystem:…, category:…)`). Do not
  introduce a shared `AppLog` helper — YAGNI for six sites in four files.
- Subsystem `com.luma.app`; category per area (e.g. `tunings`, `account`,
  `store`).
- **Error interpolation must use the compiling form** — `os.Logger` is *not* a
  drop-in for `print` on an arbitrary `Error`:
  `logger.error("… \(String(describing: error), privacy: .private)")`.
- Literal-only messages become a plain level (`.debug`/`.notice`/`.error`) with
  no privacy qualifier needed.
- Update `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`
  (lines 60–61, 75, 102) to recommend `os.Logger` instead of `print`.
- `docs/rules/swiftui.md:14` already says "Log with `os.Logger` (never `print`)"
  — no edit needed there.

### B-1 — Keychain `…ThisDeviceOnly`

`App/Account/KeychainStore.swift:19`:
`kSecAttrAccessibleAfterFirstUnlock` → `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
Same availability (background refresh still works); the credential no longer
migrates to a new device via encrypted-backup restore. That is the entire code
change.

### B-4 — Account delete-purge verify

Decision (confirmed): **Keychain only.** The JWT (`key: "jwt"`, the only Keychain
item written) is already purged by `deleteAccount()` → `api.clearJWT()` →
`keychain.delete("jwt")`, with `isSignedIn = false`. The two local caches
(`luma_tuning_cards.json`, `luma_gear_products.json`) have zero account/sign-in
dependency and intentionally survive deletion; there is no separate "account
JSON" cache file. B-4 is therefore *verify + test + document*, not new purge
code.

Testability seam:
- Introduce `protocol KeychainStoring: Sendable { func read; func write; func delete }`.
  `KeychainStore` (a struct with a single `let service`) conforms for free.
- Change `LumaAPI.keychain`'s declared type to `KeychainStoring` (default value
  stays `KeychainStore(service: "com.luma.tuner")`). This is the only production
  change — the actor's request/refresh logic is untouched.
- `KeychainStoring` **must inherit `Sendable`**: `LumaAPI.keychain` is
  `nonisolated let`, read synchronously from `AccountModel.init` (`@MainActor`)
  under Swift 6 strict concurrency.

Why a seam and not a real-Keychain test: headless CI runs unsigned
(`CODE_SIGNING_ALLOWED=NO`). A real `SecItemAdd`/`SecItemCopyMatching` risks
`errSecMissingEntitlement` or an interactive prompt that hangs CI — a hard
"never break CI" violation. The fake is deterministic.

Test fake (in `LUMA/Tests`):
- `final class InMemoryKeychain: KeychainStoring, @unchecked Sendable` with an
  `NSLock` guarding a backing dictionary. (A mutable-dict value type cannot be
  `Sendable`; the `@unchecked` + lock is the required pattern, not a shortcut.)

Tests (network-free — `deleteAccount` and `signOut` share the same `clearJWT`
purge primitive; the network leg is the *server* delete and is not relevant to
the *local* purge guarantee):
- Seed `jwt` in the fake → `await api.clearJWT()` → assert `await api.jwt == nil`
  and the fake no longer holds `jwt`.
- Build `AccountModel` over the fake with a seeded `jwt`, call `signOut()` →
  assert `isSignedIn == false`.
- Document (in the test and/or the deletion path) that `deleteAccount` reuses the
  same `clearJWT` after a successful server delete, and that the tuning/gear
  caches are account-independent and survive deletion by design.

Rejected alternatives:
- Real-Keychain integration test — CI-unsafe (see above).
- URLSession/`URLProtocol` seam to drive the full `deleteAccount()` to its purge
  — requires making the `LumaAPI` actor's session injectable, i.e. scope creep
  into the auth/networking layer, for marginal gain over testing the shared
  network-free purge primitive.

### Gate promotion (after the code is clean)

- `scripts/lib/invariant-patterns.sh`: flip `inv_check_print_in_app` and
  `inv_check_keychain` from `REVIEW:` to `HARD:`, and update each function's
  `# REVIEW:` header comment to `# HARD:`.
- `.claude/hooks/tests/invariant-patterns.test.sh`: flip the `print flagged`,
  `debugPrint flagged`, and `keychain bad` expectations from `REVIEW` to `HARD`.
  The `…ThisDeviceOnly` "keychain good" case and the test-file-exclusion cases
  must stay silent.
- The PostToolUse hook (`validate-invariants.sh`) and `ci-invariants.sh` are
  prefix-routed (`HARD:`/`REVIEW:`), so they auto-adapt — no edits there.
- Verify: `bash .claude/hooks/tests/invariant-patterns.test.sh` passes;
  `./scripts/ci-invariants.sh` → 0 HARD / 0 REVIEW.

## Sequencing & process

- **Branch first** — done: `security-code-conformance` off `main` (per the
  git-workflow rule; `git reset --hard` is blocked, so commits must not land on
  `main`).
- Task order **B-1 → A-1 → B-4 → gate promotion**. Fixes precede promotion so
  no intermediate commit is red.
- Execution via subagent-driven-development. B-4's implementer gets a capable
  model (auth-adjacent + Swift 6 concurrency); B-1/A-1/promotion are
  mechanical (cheap/standard tier).
- On completion, `git mv` the three todos
  (`P1-keychain-thisdeviceonly`, `P1-logging-oslogger-app`,
  `P2-account-delete-purge-verify`) into `docs/todos/archive/`.

## Verification

- `bash .claude/hooks/tests/invariant-patterns.test.sh` — unit tests for the
  invariant library (expectations flipped to HARD).
- `./scripts/ci-invariants.sh` — repo scan → 0 HARD / 0 REVIEW.
- `xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
  — the new B-4 tests + existing `LUMATests`.
- `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
  — iOS compile.
- `swift test --package-path Packages/TunerEngine` and
  `swift test --package-path Packages/LumaDesignSystem` — unaffected, must stay
  green.

## Out of scope

- Accessibility code fixes (C-1…C-4) — that is sub-project 3.
- B-2 (ATS) — the HARD gate already exists and the code is already compliant
  (no `NSAllowsArbitraryLoads`); nothing to change.
- B-3 (the "collects nothing" tagline) — a documentation scoping item, already
  addressed in the rule layer.
- Any change to the `LumaAPI` actor's request, retry, or token-refresh logic.
