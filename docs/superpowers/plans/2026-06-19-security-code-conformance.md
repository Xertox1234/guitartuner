# Security Code Conformance + Gate Promotion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `App/` conform to the three security rules `docs/rules/security.md` already mandates (Keychain `…ThisDeviceOnly`, `os.Logger` with `.private`, verified delete-purge), then promote the two deferred REVIEW invariant gates to HARD.

**Architecture:** Four tasks in strict order — B-1 (Keychain class), A-1 (`os.Logger` migration), B-4 (delete-purge verify via a `KeychainStoring` test seam), then gate promotion. Fixes precede promotion so every commit leaves the invariant scan green. No `LumaAPI` networking-logic changes; the only production seam is the keychain dependency's *type*.

**Tech Stack:** Swift 6 (strict concurrency), `os.Logger`, `Security` framework, Swift Testing (`@Suite`/`@Test`/`#expect`), Bash invariant library, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-06-19-security-code-conformance-design.md`

## Global Constraints

- **No rule *behaviour* changes.** The only permitted doc edit to `docs/rules/` is one clarifying parenthetical on `security.md` line 10 (Task 3). Do not add/remove/reorder any rule.
- **No networking-logic changes.** `LumaAPI`'s request / retry / `refreshToken` logic is untouched. The only change to `LumaAPI` is the declared *type* of the `keychain` property + init parameter (`KeychainStore` → `any KeychainStoring`); the default value stays `KeychainStore(service: "com.luma.tuner")`.
- **Acceptance gate:** after Task 2, and through Task 3, `./scripts/ci-invariants.sh` prints `Security invariants: 0 HARD, 0 REVIEW`. Task 4 promotes on already-clean code, so it stays `0 HARD, 0 REVIEW`. If a scan is ever non-zero after its task, a fix was missed — stop.
- **Swift 6 strict concurrency:** `KeychainStoring` inherits `Sendable` (the keychain is a `nonisolated let` read synchronously from `AccountModel.init`, a `@MainActor` context). The test fake is `final class … @unchecked Sendable` with an `NSLock` — **NOT an `actor`** (an actor forces the synchronous reads async and cascades through call sites).
- **Logging:** per-file `private static let logger = Logger(subsystem: "com.luma.app", category: "<area>")`. Match the lone precedent (`LumaFonts` is per-file) — no shared helper. `os.Logger` is **not** a drop-in for `print`: interpolate errors as `\(String(describing: error), privacy: .private)`. Literal-only messages need no privacy qualifier.
- **No force-unwrapping** in production paths. **Swift Concurrency only** (no Combine).
- **Tests:** Swift Testing, `@testable import LUMA`, in `LUMA/Tests/`.
- **Branch:** `security-code-conformance` (already created off `main`).
- **Commit footer:** end every commit message with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: B-1 — Keychain `…ThisDeviceOnly`

**Files:**
- Modify: `App/Account/KeychainStore.swift:19`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing new (behaviour-preserving constant change).

- [ ] **Step 1: Observe the REVIEW (the failing check)**

Run: `./scripts/ci-invariants.sh`
Expected (tail): a `•` line for `App/Account/KeychainStore.swift:19` and `Security invariants: 0 HARD, 5 REVIEW`.

- [ ] **Step 2: Change the accessibility class**

In `App/Account/KeychainStore.swift`, line 19, change:

```swift
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
```

to:

```swift
        // ...ThisDeviceOnly: same availability (background token refresh still
        // works) but the credential is excluded from encrypted-backup restore,
        // so it never migrates to another device. See docs/rules/security.md.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

- [ ] **Step 3: Confirm the keychain REVIEW is gone**

Run: `./scripts/ci-invariants.sh`
Expected (tail): no `KeychainStore.swift` line; `Security invariants: 0 HARD, 4 REVIEW` (the 4 remaining are the `print` files, fixed in Task 2).

- [ ] **Step 4: Confirm it compiles**

Run:
```bash
xcodegen generate
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add App/Account/KeychainStore.swift
git commit -m "fix(security): store Keychain token with ...ThisDeviceOnly (B-1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: A-1 — Migrate `App/` logging from `print` to `os.Logger`

**Files:**
- Modify: `App/Tunings/TuningCard.swift` (add `import os` + logger; site line 27)
- Modify: `App/Tunings/TuningCardStore.swift` (add `import os` + logger; site line 74)
- Modify: `App/Views/Monetization/AccountSheet.swift` (add `import os` + logger; sites lines 199, 205, 208)
- Modify: `App/Store/GearStoreModel.swift` (add `import os` + logger; site line 57)
- Modify: `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md` (lines 60–61, 75, 101–102)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing public. Each file gains a `private static let logger`.

- [ ] **Step 1: Observe the print REVIEWs (the failing check)**

Run: `./scripts/ci-invariants.sh`
Expected (tail): four `•` lines (`TuningCard.swift:27`, `TuningCardStore.swift:74`, `GearStoreModel.swift:57`, `AccountSheet.swift:199`) and `Security invariants: 0 HARD, 4 REVIEW`.

- [ ] **Step 2: `TuningCard.swift` — logger + migrate site 27**

Change the imports at the top of `App/Tunings/TuningCard.swift`:

```swift
import Foundation
import LumaDesignSystem
```

to:

```swift
import Foundation
import LumaDesignSystem
import os
```

Add the logger as the first member of `struct TuningCard` (immediately after the opening brace / before `let id: String`):

```swift
    private static let logger = Logger(subsystem: "com.luma.app", category: "tunings")
```

Replace line 27:

```swift
            print("[LUMA] TuningCard: failed to decode strings_json — card id=\(id) may be corrupt")
```

with:

```swift
            Self.logger.error("TuningCard: failed to decode strings_json — card id=\(id, privacy: .public) may be corrupt")
```

(The card id is a non-sensitive identifier, marked `.public` so the log stays diagnostic.)

- [ ] **Step 3: `TuningCardStore.swift` — logger + migrate site 74**

Change the top imports of `App/Tunings/TuningCardStore.swift` to add `import os`:

```swift
import Foundation
import LumaDesignSystem
import os
```

Add the logger as the first member of `final class TuningCardStore` (before `var cards`):

```swift
    private static let logger = Logger(subsystem: "com.luma.app", category: "tunings")
```

Replace line 74:

```swift
            print("[LUMA] TuningCardStore: cache write failed — \(error)")
```

with:

```swift
            Self.logger.error("TuningCardStore: cache write failed — \(String(describing: error), privacy: .private)")
```

- [ ] **Step 4: `GearStoreModel.swift` — logger + migrate site 57**

Change the top import of `App/Store/GearStoreModel.swift`:

```swift
import Foundation
```

to:

```swift
import Foundation
import os
```

Add the logger as the first member of `final class GearStoreModel` (before `var products`):

```swift
    private static let logger = Logger(subsystem: "com.luma.app", category: "store")
```

Replace line 57:

```swift
            print("[LUMA] GearStoreModel: cache write failed — \(error)")
```

with:

```swift
            Self.logger.error("GearStoreModel: cache write failed — \(String(describing: error), privacy: .private)")
```

- [ ] **Step 5: `AccountSheet.swift` — logger + migrate sites 199, 205, 208**

Change the top imports of `App/Views/Monetization/AccountSheet.swift`:

```swift
import SwiftUI
import AuthenticationServices
import LumaDesignSystem
```

to:

```swift
import SwiftUI
import AuthenticationServices
import LumaDesignSystem
import os
```

Add the logger as the first member of `struct AccountSheet: View` (before `@Bindable var accountModel`):

```swift
    private static let logger = Logger(subsystem: "com.luma.app", category: "account")
```

Replace the three sites. Line 199:

```swift
                print("[LUMA] Apple sign-in: unexpected credential type")
```
→
```swift
                Self.logger.error("Apple sign-in: unexpected credential type")
```

Line 205:

```swift
                    print("[LUMA] Apple sign-in: success")
```
→
```swift
                    Self.logger.notice("Apple sign-in: success")
```

Line 208 (auth path with a raw error → `.private`):

```swift
                    print("[LUMA] Apple sign-in: failed — \(error)")
```
→
```swift
                    Self.logger.error("Apple sign-in: failed — \(String(describing: error), privacy: .private)")
```

- [ ] **Step 6: Update the solution doc's `print` prescription**

In `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`:

Replace lines 60–61:

```
downgrade the assert to a non-fatal log (matching the codebase: `print("[LUMA] …")`
is the established convention — there is no `os.Logger` in `App/`):
```
with:
```
downgrade the assert to a non-fatal log via `os.Logger` with `.private` on any
interpolated error (`docs/rules/security.md`; each `App/` file declares its own
`private static let logger = Logger(subsystem: "com.luma.app", category: …)`):
```

Replace the `print` inside the example block (line 75):

```swift
        print("[LUMA] TuningCardStore: cache write failed — \(error)")
```
with:
```swift
        Self.logger.error("TuningCardStore: cache write failed — \(String(describing: error), privacy: .private)")
```

Replace the rule-of-thumb sentence (lines 101–102):

```
network-response, or external-data path — log with `print("[LUMA] …")` and degrade.**
```
with:
```
network-response, or external-data path — log with `os.Logger` (`.private` on any interpolated error) and degrade.**
```

- [ ] **Step 7: Confirm no `print` remains and the scan is clean**

Run:
```bash
grep -rnE '\b(print|debugPrint)\(' App --include='*.swift' | grep -vE 'Tests/|Test\.swift|Tests\.swift|/Bench/|Benchmark'
./scripts/ci-invariants.sh
```
Expected: the grep prints nothing; the scan tail is `Security invariants: 0 HARD, 0 REVIEW`.

- [ ] **Step 8: Confirm it compiles**

Run:
```bash
xcodegen generate
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 9: Commit**

```bash
git add App/Tunings/TuningCard.swift App/Tunings/TuningCardStore.swift App/Store/GearStoreModel.swift App/Views/Monetization/AccountSheet.swift docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md
git commit -m "fix(security): migrate App/ logging from print to os.Logger (A-1)

Per-file Logger(subsystem: com.luma.app); .private on raw error
interpolations on cache/auth paths. Updates the app-support solution
doc's print prescription to os.Logger.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: B-4 — Verify account delete purges credentials (KeychainStoring seam)

**Files:**
- Modify: `App/Account/KeychainStore.swift` (add `protocol KeychainStoring`; conform `KeychainStore`)
- Modify: `App/Networking/LumaAPI.swift:9,17-18` (change `keychain` type to `any KeychainStoring`)
- Modify: `App/Account/AccountModel.swift:64-73` (clarifying comment in `deleteAccount()`)
- Modify: `docs/rules/security.md` line 10 (clarifying parenthetical)
- Create: `LUMA/Tests/AccountPurgeTests.swift` (fake + tests)

**Interfaces:**
- Produces:
  - `protocol KeychainStoring: Sendable { @discardableResult func write(key: String, value: String) -> Bool; func read(key: String) -> String?; func delete(key: String) }`
  - `struct KeychainStore: KeychainStoring` (already has matching members)
  - `LumaAPI.init(baseURL:keychain:)` now takes `keychain: any KeychainStoring = KeychainStore(service: "com.luma.tuner")`
- Consumes (from existing code): `LumaAPI.jwt: String?` (actor-isolated, `await`), `LumaAPI.clearJWT()` (actor, `await`), `AccountModel(api:)`, `AccountModel.isSignedIn`, `AccountModel.signOut()`.

- [ ] **Step 1: Write the failing test**

Create `LUMA/Tests/AccountPurgeTests.swift`:

```swift
import Foundation
import Testing
@testable import LUMA

/// In-memory KeychainStoring for deterministic, CI-safe tests. Must be a
/// class + lock (NOT an actor): AccountModel.init reads the keychain
/// synchronously, and an actor would force those reads async. @unchecked
/// Sendable is required because the dictionary is mutable; the NSLock makes
/// the concurrent access safe.
final class InMemoryKeychain: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: String] = [:]

    @discardableResult
    func write(key: String, value: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        store[key] = value
        return true
    }

    func read(key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    func delete(key: String) {
        lock.lock(); defer { lock.unlock() }
        store[key] = nil
    }
}

@Suite("Account deletion purges credentials")
@MainActor
struct AccountPurgeTests {
    // deleteAccount and signOut share the same network-free local purge
    // (api.clearJWT()); the network leg is the server delete and is not
    // relevant to the local-credential guarantee. We test the shared primitive.

    @Test func clearJWTRemovesTokenFromKeychain() async {
        let keychain = InMemoryKeychain()
        keychain.write(key: "jwt", value: "seed-token")
        let api = LumaAPI(keychain: keychain)
        #expect(await api.jwt == "seed-token")

        await api.clearJWT()

        #expect(await api.jwt == nil)
        #expect(keychain.read(key: "jwt") == nil)
    }

    @Test func signOutClearsTokenAndResetsState() async {
        let keychain = InMemoryKeychain()
        keychain.write(key: "jwt", value: "seed-token")
        let api = LumaAPI(keychain: keychain)
        let model = AccountModel(api: api)
        #expect(model.isSignedIn == true)   // init read the seeded token

        await model.signOut()

        #expect(model.isSignedIn == false)
        #expect(keychain.read(key: "jwt") == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails (does not compile)**

Run:
```bash
xcodegen generate
xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: build/compile failure — `cannot find type 'KeychainStoring' in scope` (and `LumaAPI(keychain:)` won't accept the fake yet).

- [ ] **Step 3: Add the `KeychainStoring` protocol and conform `KeychainStore`**

In `App/Account/KeychainStore.swift`, insert the protocol above `struct KeychainStore`, and add the conformance:

```swift
import Foundation
import Security

/// Abstraction over Keychain read/write/delete so tests can inject an
/// in-memory fake. Headless CI runs unsigned, where a real SecItem call risks
/// errSecMissingEntitlement or an interactive prompt — the fake keeps the
/// delete-purge test deterministic. `Sendable` because `LumaAPI.keychain` is a
/// `nonisolated let` read synchronously from `AccountModel.init` (@MainActor)
/// under Swift 6 strict concurrency.
protocol KeychainStoring: Sendable {
    @discardableResult func write(key: String, value: String) -> Bool
    func read(key: String) -> String?
    func delete(key: String)
}

/// Thread-safe Keychain read/write for a single service namespace.
struct KeychainStore: KeychainStoring {
    let service: String
```

(Leave the body of `KeychainStore` — `write`/`read`/`delete` — unchanged; their signatures already match the protocol.)

- [ ] **Step 4: Point `LumaAPI` at the protocol**

In `App/Networking/LumaAPI.swift`, change line 9:

```swift
    nonisolated let keychain: KeychainStore
```
to:
```swift
    nonisolated let keychain: any KeychainStoring
```

and the init parameter (lines 17–18):

```swift
    init(baseURL: URL = LumaConfig.apiBaseURL,
         keychain: KeychainStore = KeychainStore(service: "com.luma.tuner")) {
```
to:
```swift
    init(baseURL: URL = LumaConfig.apiBaseURL,
         keychain: any KeychainStoring = KeychainStore(service: "com.luma.tuner")) {
```

(Everything else in `LumaAPI` — `jwt`, `setJWT`, `clearJWT`, `perform`, `refreshToken` — is unchanged; they only call `read`/`write`/`delete`, all in the protocol.)

- [ ] **Step 5: Add the clarifying comment in `deleteAccount()`**

In `App/Account/AccountModel.swift`, in `deleteAccount()`, replace this block (include the `guard` so the match is unique — the same `clearJWT()`/`isSignedIn = false` pair also appears in `signOut()`):

```swift
        guard response.deleted == true else {
            throw LumaAPIError.server("Account deletion failed", 0)
        }
        await api.clearJWT()
        isSignedIn = false
    }
```
with:
```swift
        guard response.deleted == true else {
            throw LumaAPIError.server("Account deletion failed", 0)
        }
        // Local purge: clearJWT() deletes the only Keychain item ("jwt"). There
        // is no separate account-JSON cache; the tuning/gear caches are not
        // account-scoped and intentionally survive deletion (docs/rules/security.md).
        await api.clearJWT()
        isSignedIn = false
    }
```

- [ ] **Step 6: Clarify `security.md` line 10**

In `docs/rules/security.md`, line 10, replace:

```
declared in `App/PrivacyInfo.xcprivacy`. Account deletion must purge Keychain tokens *and* cached account JSON. Scope privacy claims precisely:
```
with:
```
declared in `App/PrivacyInfo.xcprivacy`. Account deletion must purge Keychain tokens *and* any cached account JSON (as of 2026-06-19 there is no separate account-JSON cache — account state derives from the Keychain token; the `luma_tuning_cards.json` / `luma_gear_products.json` caches are not account-scoped and survive deletion by design). Scope privacy claims precisely:
```

- [ ] **Step 7: Run the tests to verify they pass**

Run:
```bash
xcodegen generate
xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`; `AccountPurgeTests` both pass, and the existing `LUMATests` still pass.

- [ ] **Step 8: Confirm the scan is still clean**

Run: `./scripts/ci-invariants.sh`
Expected (tail): `Security invariants: 0 HARD, 0 REVIEW`. (The fake lives in `LUMA/Tests/`, excluded from the scan; no production violation added.)

- [ ] **Step 9: Commit**

```bash
git add App/Account/KeychainStore.swift App/Networking/LumaAPI.swift App/Account/AccountModel.swift docs/rules/security.md LUMA/Tests/AccountPurgeTests.swift
git commit -m "test(security): verify account delete purges Keychain token (B-4)

Introduce KeychainStoring seam (Sendable) + in-memory fake so the
credential-purge guarantee is tested deterministically without real
Keychain/network. Tests the shared network-free clearJWT/signOut
primitive that deleteAccount reuses. Clarifies security.md that no
separate account-JSON cache exists.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Promote the print + Keychain gates to HARD

**Files:**
- Modify: `scripts/lib/invariant-patterns.sh` (`inv_check_print_in_app`, `inv_check_keychain`)
- Modify: `.claude/hooks/tests/invariant-patterns.test.sh` (3 expectations)
- Move: `docs/todos/P1-keychain-thisdeviceonly.md`, `docs/todos/P1-logging-oslogger-app.md`, `docs/todos/P2-account-delete-purge-verify.md` → `docs/todos/archive/`

**Interfaces:**
- Consumes: the now-clean code from Tasks 1–3 (so promotion lands on `0 HARD, 0 REVIEW`).
- Produces: nothing for later tasks (final task).

- [ ] **Step 1: Flip the unit-test expectations (the new spec)**

In `.claude/hooks/tests/invariant-patterns.test.sh`, change the three `print`/`debugPrint`/`keychain bad` expectations from `REVIEW` to `HARD`.

Line 32:
```bash
expect "print flagged"     "$(mk App/Engine/LiveTunerModel.swift 'print("[LUMA] hi")')" REVIEW 'print'
```
→
```bash
expect "print flagged"     "$(mk App/Engine/LiveTunerModel.swift 'print("[LUMA] hi")')" HARD 'print'
```

Line 33:
```bash
expect "debugPrint flagged" "$(mk App/Engine/X.swift 'debugPrint(thing)')" REVIEW 'print'
```
→
```bash
expect "debugPrint flagged" "$(mk App/Engine/X.swift 'debugPrint(thing)')" HARD 'print'
```

Line 38:
```bash
expect "keychain bad"  "$(mk App/Account/KeychainStore.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlock')" REVIEW 'Keychain'
```
→
```bash
expect "keychain bad"  "$(mk App/Account/KeychainStore.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlock')" HARD 'Keychain'
```

(Leave `keychain good`, `print in tests ok`, `fingerprint ok`, and the three test-file-exclusion `silent` cases unchanged — they must stay silent.)

- [ ] **Step 2: Run the unit tests to verify they now fail (RED)**

Run: `bash .claude/hooks/tests/invariant-patterns.test.sh`
Expected: failures on `print flagged`, `debugPrint flagged`, `keychain bad` (they still emit `REVIEW:`, but the tests now expect `HARD:`). Non-zero exit.

- [ ] **Step 3: Promote `inv_check_print_in_app`**

In `scripts/lib/invariant-patterns.sh`, change the header comment and the emit line of `inv_check_print_in_app`.

Comment (line 67):
```bash
# REVIEW: print/debugPrint in App production code
```
→
```bash
# HARD: print/debugPrint in App production code (use os.Logger with .private)
```

Emit (line 71):
```bash
  [ -n "$hit" ] && echo "REVIEW:$1:${hit%%:*}: print/debugPrint in App/ — use os.Logger with .private for PII/secret paths (docs/rules/security.md)"
```
→
```bash
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: print/debugPrint in App/ — use os.Logger with .private for PII/secret paths (docs/rules/security.md)"
```

- [ ] **Step 4: Promote `inv_check_keychain`**

In `scripts/lib/invariant-patterns.sh`, change the header comment and the emit line of `inv_check_keychain`.

Comment (line 74):
```bash
# REVIEW: Keychain AfterFirstUnlock without ThisDeviceOnly (substring-trap safe)
```
→
```bash
# HARD: Keychain AfterFirstUnlock without ThisDeviceOnly (substring-trap safe)
```

Emit (line 79):
```bash
  [ -n "$hit" ] && echo "REVIEW:$1:${hit%%:*}: Keychain AfterFirstUnlock without ThisDeviceOnly — backup-restore-eligible; prefer …AfterFirstUnlockThisDeviceOnly (docs/rules/security.md)"
```
→
```bash
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: Keychain AfterFirstUnlock without ThisDeviceOnly — backup-restore-eligible; prefer …AfterFirstUnlockThisDeviceOnly (docs/rules/security.md)"
```

- [ ] **Step 5: Run the unit tests to verify they pass (GREEN)**

Run: `bash .claude/hooks/tests/invariant-patterns.test.sh`
Expected: `15 passed, 0 failed` (all `expect`/`silent` cases pass with the flipped severities).

- [ ] **Step 6: Confirm the repo scan stays clean under HARD**

Run: `./scripts/ci-invariants.sh; echo "exit=$?"`
Expected (tail): `Security invariants: 0 HARD, 0 REVIEW` and `exit=0`. (Tasks 1–2 cleaned every production hit, so promotion finds nothing to fail on.)

- [ ] **Step 7: Archive the three completed todos**

```bash
git mv docs/todos/P1-keychain-thisdeviceonly.md docs/todos/archive/P1-keychain-thisdeviceonly.md
git mv docs/todos/P1-logging-oslogger-app.md docs/todos/archive/P1-logging-oslogger-app.md
git mv docs/todos/P2-account-delete-purge-verify.md docs/todos/archive/P2-account-delete-purge-verify.md
```

- [ ] **Step 8: Commit**

```bash
git add scripts/lib/invariant-patterns.sh .claude/hooks/tests/invariant-patterns.test.sh
git commit -m "feat(security): promote print + Keychain invariant gates to HARD

App/ is now clean of print and uses ...ThisDeviceOnly, so both gates
move from REVIEW to HARD (local hook + CI). Unit tests flipped to HARD.
Archives the three completed P1/P2 security todos.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Full verification (run before finishing the branch)

```bash
bash .claude/hooks/tests/invariant-patterns.test.sh          # 15 passed, 0 failed
./scripts/ci-invariants.sh; echo "exit=$?"                   # 0 HARD, 0 REVIEW; exit=0
xcodegen generate
xcodebuild test -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20   # TEST SUCCEEDED
xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5  # BUILD SUCCEEDED
swift test --package-path Packages/TunerEngine                # unaffected, must stay green
swift test --package-path Packages/LumaDesignSystem           # unaffected, must stay green
```

**PR-body / archive note (transparency at the seam):** state that B-4's tests exercise the shared network-free purge primitive (`clearJWT`/`signOut`) that `deleteAccount` reuses — not `deleteAccount` end-to-end — because the `LumaAPI` actor's `URLSession` is not injectable and `deleteAccount`'s only *local* purge action is `clearJWT()`. Deliberate, documented choice.

## Out of scope

- Accessibility code (C-1…C-4) — sub-project 3.
- B-2 (ATS): gate already exists, code already compliant.
- B-3 ("collects nothing" tagline): addressed in the rule layer already.
- Any change to `LumaAPI`'s request / retry / token-refresh logic.
