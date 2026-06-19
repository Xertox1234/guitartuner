# Security & Accessibility Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the cross-cutting *security* and *accessibility* concerns a home in LUMA's rule system, wire them into the auto-injection hook, and enforce the deterministic subset locally + in CI — capturing the deferred code work as tracked todos.

**Architecture:** Two new canonical rule files (`docs/rules/security.md`, `docs/rules/accessibility.md`); cross-cutting blocks added to the existing `get_domains` mapping so they co-inject alongside a file's architectural domain; a single shared bash library (`scripts/lib/invariant-patterns.sh`) of deterministic checks consumed by both the local PostToolUse hook and a new CI script; a PR checklist for the non-grep-able items; and seven `docs/todos/` entries for the code fixes.

**Tech Stack:** Bash (hooks + CI script), Markdown (rules/todos/spec), GitHub Actions YAML. No application Swift is modified.

**Spec:** `docs/superpowers/specs/2026-06-19-governance-security-accessibility-design.md`

## Global Constraints

- **No application code changes.** This sub-project touches only `docs/`, `.claude/hooks/`, `scripts/`, `.github/`, and `CLAUDE.md`. No file under `App/` or `Packages/` is modified.
- **Single source of truth.** Each cross-cutting rule is owned canonically by its home file; domain files (`strobe.md`, `swiftui.md`, `capture.md`) link up, never duplicate.
- **Staged gating — only hard-gate what the code already satisfies.** HARD+CI now: ATS exception, `appending(component:)` in route scope, networking outside the allow-list. Local REVIEW only (promoted later by sub-project #2): `print`/`debugPrint` in `App/`, Keychain without `…ThisDeviceOnly`.
- **Grep-pattern cautions (verbatim from spec §5.4):** Keychain check must match `AfterFirstUnlock` **not** followed by `ThisDeviceOnly` (the correct form is a superstring). `print` check must be anchored `\b(print|debugPrint)\(`. `appending(component:)` enforced **only** within `App/Networking/` + `*LumaAPI*`.
- **Branch:** all work lands on `governance-security-accessibility` (already checked out). Never commit to `main`.
- **Verification baseline:** `./scripts/ci-invariants.sh` must exit 0 against the current repo at the end of Task 7 (proves the now-gated rules are genuinely clean).

---

### Task 1: Create the two home rule files + de-scatter domain files

**Files:**
- Create: `docs/rules/security.md`
- Create: `docs/rules/accessibility.md`
- Modify: `docs/rules/swiftui.md` (lines 7, 13, 14 — replace embedded cross-cutting rules with pointers)
- Modify: `docs/rules/strobe.md` (line 7 — add canonical pointer)
- Modify: `docs/rules/capture.md` (line 8 — add canonical pointer)

**Interfaces:**
- Produces: `docs/rules/security.md`, `docs/rules/accessibility.md` (consumed by Task 2's injection wiring and Task 3's CLAUDE.md table).

- [ ] **Step 1: Write `docs/rules/security.md`**

```markdown
# Security rules

Cross-cutting domain — co-injected alongside the architectural domain when editing
networking, account, persistence, capture-permission, or privacy-surface files.

- **Audio privacy is architectural.** `TunerEngine` has no networking; audio is never recorded, stored, or transmitted. Enforced by package boundaries, not convention.
- **All backend networking lives in `LumaAPI` only.** HTTPS-only — never add an ATS exception (`NSAllowsArbitraryLoads`). The opt-in account/monetization stack (`LumaAPI`, `AccountModel`, `TuningCardStore`, `GearStoreModel`, `LumaApp`) is the only place `URLSession` belongs.
- **API route construction** goes through `LumaAPI.buildURL` / `appending(path:)`, never `appending(component:)` — it percent-encodes slashes and silently breaks multi-segment routes (`auth/apple` → `auth%2Fapple`). Scope: route strings only; `appending(component:)` is correct for a single-segment *filesystem* name (the cache stores' `…json` files). See `docs/solutions/logic-errors/url-appending-component-encodes-slashes-2026-06-15.md`.
- **Tokens and secrets live in the Keychain**, never `UserDefaults` or a JSON cache. Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — preserves background token refresh while keeping the credential off encrypted backups (no device-migration leak).
- **Account data minimization.** Only the user's email is collected, opt-in, and declared in `App/PrivacyInfo.xcprivacy`. Account deletion must purge Keychain tokens *and* cached account JSON. Scope privacy claims precisely: "audio never leaves the device; no account is required to tune; the optional account collects only email."
- **Logging.** Use `os.Logger` with `.private` qualifiers in `App/`. Never `print`/`debugPrint` PII, secrets, or raw error objects on a network or auth path — `print` is unredacted stderr.
- **Never `assertionFailure`/`fatalError`/`precondition` on a recoverable path** (cache write, network response, external-data decode). Log and degrade to stale/empty data. See `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`.
- **Keep `PrivacyInfo.xcprivacy` accurate.** Declare any newly collected data type or required-reason API.
- **macOS audio entitlement.** Sandboxed/notarized macOS builds need `com.apple.security.device.audio-input`. See `docs/solutions/macos-audio-input-entitlement-2026-06-12.md`.
```

- [ ] **Step 2: Write `docs/rules/accessibility.md`**

```markdown
# Accessibility rules

Cross-cutting domain — co-injected when editing any user-facing file (App views,
design-system components, strobe renderers, gallery).

- **Reduce Motion.** Honor `@Environment(\.accessibilityReduceMotion)`; substitute the `ReducedGauge` readout — do not merely slow the animation. (Operational detail lives in `strobe.md`.)
- **Reduce Transparency.** Honor `@Environment(\.accessibilityReduceTransparency)`; attenuate additive bloom (`.bloom()`) and `FieldWash` translucency when enabled.
- **Dynamic Type.** Chrome / settings / informational text scales with the user's content-size preference — use `.custom(_:size:relativeTo:)` or `@ScaledMetric`, never a fixed `.custom(_:size:)` for body text. The primary instrument readout (note name, strobe) may opt out of scaling, but the opt-out must be deliberate and commented.
- **VoiceOver.** Every interactive or stateful component carries an `accessibilityLabel`. Pitch-bearing views expose a live `accessibilityValue` ("in tune", signed cents). New components ship with labels — same bar as the `#Preview` requirement.
- **Color independence.** Never signal state by color alone; honor `@Environment(\.accessibilityDifferentiateWithoutColor)`. Preserve the existing redundancy: textual state line + strobe scroll direction + signed cents. Compact/menu-bar affordances need a non-color cue.
- **Contrast.** State colors and text meet WCAG AA (4.5:1 text / 3:1 graphics) in **both** appearances — validate light mode explicitly (dark-first must not leave light under-checked).
- **Photosensitivity.** The off-pitch strobe animation is verified against the WCAG 2.3.1 flash threshold (rate × luminance-delta × area); record the check in `strobe.md`.
- **Haptics.** The in-tune lock haptic is a non-visual confirmation channel — preserve it.
```

- [ ] **Step 3: De-scatter `docs/rules/swiftui.md` — replace line 7 (networking/audio)**

Replace the existing line 7 (`- **Audio never leaves the device.** TunerEngine has no networking; the privacy guarantee is architectural. The opt-in account/monetization stack (LumaAPI, AccountModel, TuningCardStore, GearStoreModel) uses URLSession for backend calls with explicit user consent — this is intentional. Do not add networking outside of LumaAPI.`) with:

```markdown
- **Networking & audio privacy:** all backend calls go through `LumaAPI`; audio never leaves the device. Canonical: `docs/rules/security.md`.
```

- [ ] **Step 4: De-scatter `docs/rules/swiftui.md` — replace line 13 (URL construction)**

Replace the existing line 13 (`- URL construction in LumaAPI: always use LumaAPI.buildURL(base:path:) — never URL.appending(component:) directly. appending(component:) percent-encodes slashes, silently turning "auth/apple" into auth%2Fapple and breaking routing. appending(path:) (wrapped by buildURL) treats slashes as separators.`) with:

```markdown
- **URL/route construction:** use `LumaAPI.buildURL` / `appending(path:)`, never `appending(component:)` for routes. Canonical: `docs/rules/security.md`.
```

- [ ] **Step 5: De-scatter `docs/rules/swiftui.md` — fix the logging contradiction on line 14**

In line 14, replace the substring `Log with \`print("[LUMA] …")\` and degrade to stale/empty data.` with:

```markdown
Log with `os.Logger` (never `print`) and degrade to stale/empty data. Canonical: `docs/rules/security.md`.
```

(This removes the only direct rule-vs-rule contradiction: `swiftui.md` previously prescribed `print`, which `security.md` now forbids.)

- [ ] **Step 6: Add canonical pointer to `docs/rules/strobe.md` line 7**

Append to the end of the existing Reduce Motion bullet (line 7), after `do not just slow the animation.`:

```markdown
 Canonical (with Reduce Transparency, Dynamic Type, VoiceOver, contrast): `docs/rules/accessibility.md`.
```

- [ ] **Step 7: Add canonical pointer to `docs/rules/capture.md` line 8**

Append to the end of the existing audio-privacy bullet (line 8), after `Do not add any persistence or network calls to the capture path.`:

```markdown
 Canonical: `docs/rules/security.md`.
```

- [ ] **Step 8: Verify the rule files are present and the contradiction is gone**

Run:
```bash
test -f docs/rules/security.md && test -f docs/rules/accessibility.md && echo "homes exist"
grep -n 'print("\[LUMA\]' docs/rules/swiftui.md || echo "no print-prescription left in swiftui.md"
grep -c '^- ' docs/rules/security.md docs/rules/accessibility.md
```
Expected: `homes exist`; `no print-prescription left in swiftui.md`; security.md ≥ 9 bullets, accessibility.md ≥ 8 bullets.

- [ ] **Step 9: Commit**

```bash
git add docs/rules/security.md docs/rules/accessibility.md docs/rules/swiftui.md docs/rules/strobe.md docs/rules/capture.md
git commit -m "docs(rules): add security & accessibility home rule files; de-scatter domain files

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Wire security & accessibility into the domain map

**Files:**
- Modify: `.claude/hooks/lib/domain-map.sh` (add two `if` blocks to `get_domains`; two cases to `domain_rank`)
- Create: `.claude/hooks/tests/domain-map.test.sh`

**Interfaces:**
- Consumes: nothing (pure path→label function).
- Produces: `get_domains` now emits `security` / `accessibility` for matching paths; `domain_rank security`→5, `domain_rank accessibility`→15. Task 3 relies on this for injection.

- [ ] **Step 1: Write the failing test `.claude/hooks/tests/domain-map.test.sh`**

```bash
#!/bin/bash
# Tests for lib/domain-map.sh get_domains() cross-cutting resolution.
# Run:  bash .claude/hooks/tests/domain-map.test.sh
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/lib/domain-map.sh"
PASS=0; FAIL=0
want() { # want <path> <domain>
  if get_domains "$1" | grep -qx "$2"; then PASS=$((PASS+1)); printf '  ok   %s -> %s\n' "$1" "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL %s -> %s (got: %s)\n' "$1" "$2" "$(get_domains "$1" | tr '\n' ',')"; fi
}
deny() { # deny <path> <domain>
  if get_domains "$1" | grep -qx "$2"; then FAIL=$((FAIL+1)); printf '  FAIL %s should NOT map to %s\n' "$1" "$2"
  else PASS=$((PASS+1)); printf '  ok   %s !-> %s\n' "$1" "$2"; fi
}
want "/r/App/Account/KeychainStore.swift"        security
want "/r/App/Account/KeychainStore.swift"        swiftui
want "/r/App/Networking/LumaAPI.swift"           security
want "/r/App/Info.plist"                         security
want "/r/App/LUMA.entitlements"                  security
want "/r/App/PrivacyInfo.xcprivacy"              security
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift" accessibility
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift" design-system
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/AuroraStrobe.swift"  accessibility
want "/r/App/LiveTunerScreen.swift"              accessibility
deny "/r/Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift" security
deny "/r/Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift" accessibility
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash .claude/hooks/tests/domain-map.test.sh`
Expected: FAIL — the `security` / `accessibility` assertions fail (those domains aren't emitted yet).

- [ ] **Step 3: Add the two `if` blocks to `get_domains` in `.claude/hooks/lib/domain-map.sh`**

Insert immediately before the closing `}` of `get_domains()` (after the `testing` block):

```bash
  # security — cross-cutting: networking, auth/token storage, persistence, privacy surface
  if [[ "$path" == */App/Networking/* ]] || [[ "$path" == */App/Account/* ]] || \
     [[ "$path" == */App/Persistence/* ]] || [[ "$path" == */App/Store/* ]] || \
     [[ "$path" == *LumaAPI* ]] || [[ "$path" == *LumaConfig* ]] || \
     [[ "$path" == *Keychain* ]] || [[ "$path" == *CacheFile* ]] || \
     [[ "$path" == *MicrophonePermission* ]] || \
     [[ "$path" == *.entitlements ]] || [[ "$path" == *Info.plist ]] || \
     [[ "$path" == *PrivacyInfo.xcprivacy ]]; then
    echo "security"
  fi

  # accessibility — cross-cutting: anything user-facing
  if [[ "$path" == */App/*.swift ]] || [[ "$path" == */Components/* ]] || \
     [[ "$path" == */Strobe/* ]] || [[ "$path" == */Gallery/* ]]; then
    echo "accessibility"
  fi
```

- [ ] **Step 4: Add the two ranks to `domain_rank` in the same file**

In the `case` inside `domain_rank()`, add these two lines before the `*)` default:

```bash
    security)      echo 5  ;;
    accessibility) echo 15 ;;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash .claude/hooks/tests/domain-map.test.sh`
Expected: PASS — `N passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add .claude/hooks/lib/domain-map.sh .claude/hooks/tests/domain-map.test.sh
git commit -m "feat(hooks): map security & accessibility as cross-cutting domains

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Tag solutions, register domains in CLAUDE.md, verify injection end-to-end

**Files:**
- Modify: `docs/solutions/macos-audio-input-entitlement-2026-06-12.md` (tags)
- Modify: `docs/solutions/mic-permission-denied-settings-deeplink-2026-06-12.md` (tags)
- Modify: `docs/solutions/logic-errors/url-appending-component-encodes-slashes-2026-06-15.md` (tags)
- Modify: `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md` (tags)
- Modify: `CLAUDE.md` (`## Domains` table)

**Interfaces:**
- Consumes: `security` domain + `docs/rules/security.md` from Tasks 1–2.
- Produces: nothing downstream depends on this; it completes the inform side.

- [ ] **Step 1: Add the `security` tag to the four solution frontmatters**

Apply each exact edit:

`docs/solutions/macos-audio-input-entitlement-2026-06-12.md`: `tags: [capture, pipeline]` → `tags: [capture, pipeline, security]`

`docs/solutions/mic-permission-denied-settings-deeplink-2026-06-12.md`: `tags: [swiftui]` → `tags: [swiftui, security]`

`docs/solutions/logic-errors/url-appending-component-encodes-slashes-2026-06-15.md`: `tags: [swiftui]` → `tags: [swiftui, security]`

`docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`: `tags: [swiftui]` → `tags: [swiftui, security]`

- [ ] **Step 2: Add two rows to the `## Domains` table in `CLAUDE.md`**

Insert after the `testing` row:

```markdown
| `security` | `App/Networking/*`, `App/Account/*`, `App/Persistence/*`, `App/Store/*`, `*.entitlements`, `Info.plist`, `PrivacyInfo.xcprivacy` (cross-cutting, co-injected) | `docs/rules/security.md` |
| `accessibility` | `App/*.swift`, `Components/*`, `Strobe/*`, `Gallery/*` (cross-cutting, co-injected) | `docs/rules/accessibility.md` |
```

- [ ] **Step 3: Verify the solution matcher finds the tagged files**

Run:
```bash
grep -rlE '^tags:.*\bsecurity\b' docs/solutions --include='*.md' | sort
```
Expected: exactly the four files edited in Step 1.

- [ ] **Step 4: Verify full injection end-to-end (rules + tagged solutions appear, valid JSON)**

Run (simulates a PreToolUse edit of a security file):
```bash
LUMA_PATTERN_INJECT_NO_DEDUP=1 \
  jq -nc '{tool_name:"Edit",tool_input:{file_path:"'"$PWD"'/App/Account/KeychainStore.swift"}}' \
  | bash .claude/hooks/inject-patterns.sh \
  | jq -r '.additionalContext' | grep -E 'Security rules|security.md|url-appending' | head
```
Expected: non-empty — the security rules block and at least one `security`-tagged solution reference appear, and the hook emitted valid JSON (the outer `jq -r` did not error).

- [ ] **Step 5: Commit**

```bash
git add docs/solutions/macos-audio-input-entitlement-2026-06-12.md docs/solutions/mic-permission-denied-settings-deeplink-2026-06-12.md docs/solutions/logic-errors/url-appending-component-encodes-slashes-2026-06-15.md docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md CLAUDE.md
git commit -m "docs: tag security solutions and register security/accessibility domains

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Static governance docs — todo template enum, the seven todos, PR template

**Files:**
- Modify: `docs/todos/_TEMPLATE.md` (domain enum)
- Create: `docs/todos/P1-logging-oslogger-app.md`
- Create: `docs/todos/P1-keychain-thisdeviceonly.md`
- Create: `docs/todos/P2-account-delete-purge-verify.md`
- Create: `docs/todos/P2-reduce-transparency.md`
- Create: `docs/todos/P2-dynamic-type-chrome.md`
- Create: `docs/todos/P2-contrast-color-independence.md`
- Create: `docs/todos/P3-strobe-photosensitivity-check.md`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the backlog feeding sub-projects #2/#3; no downstream task depends on it.

- [ ] **Step 1: Extend the `domain:` enum in `docs/todos/_TEMPLATE.md`**

Replace `domain: dsp           # dsp · pipeline · capture · strobe · swiftui · design-system · testing · hooks · other` with:

```markdown
domain: dsp           # dsp · pipeline · capture · strobe · swiftui · design-system · testing · security · accessibility · hooks · other
```

- [ ] **Step 2: Create `docs/todos/P1-logging-oslogger-app.md`**

```markdown
---
priority: P1
status: open
domain: security
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (A-1)
---

# Migrate App/ logging from print to os.Logger, then promote the gate to HARD/CI

## Problem

`App/` logs recoverable-path failures with `print("[LUMA] …")`, including raw `\(error)` objects on network/auth paths that handle email + tokens. `print` is unredacted stderr — no `.private` redaction, no levels. `docs/rules/security.md` now requires `os.Logger`.

## Fix

- Introduce an `os.Logger` (subsystem `com.luma.app`) per area; replace `print("[LUMA] …")` call sites in `App/` with logger calls, using `\(value, privacy: .private)` on any error/PII interpolation.
- Update the `application-support-not-created` solution's print recommendation to point to `os.Logger`.
- In `scripts/lib/invariant-patterns.sh`, promote `inv_check_print_in_app` from `REVIEW:` to `HARD:` and confirm `./scripts/ci-invariants.sh` still exits 0.

## Files

- `App/**/*.swift` (all `print("[LUMA]` call sites)
- `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`
- `scripts/lib/invariant-patterns.sh` (`inv_check_print_in_app`)

## Verification

Build the app (`xcodebuild build`), run `./scripts/ci-invariants.sh` → 0 HARD. UI-only; no DSP benchmark involved.
```

- [ ] **Step 3: Create `docs/todos/P1-keychain-thisdeviceonly.md`**

```markdown
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
```

- [ ] **Step 4: Create `docs/todos/P2-account-delete-purge-verify.md`**

```markdown
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
```

- [ ] **Step 5: Create `docs/todos/P2-reduce-transparency.md`**

```markdown
---
priority: P2
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-1)
---

# Honor Reduce Transparency in bloom and FieldWash

## Problem

`docs/rules/accessibility.md` requires honoring `accessibilityReduceTransparency`, but nothing in the design system reads it. Additive bloom (`Bloom.swift`) and `FieldWash.swift` lean on translucency.

## Fix

- Read `@Environment(\.accessibilityReduceTransparency)`; when enabled, attenuate bloom intensity / wash opacity (or substitute a solid treatment) in `Bloom` and `FieldWash`.
- Add `#Preview`s (dark + light) with the trait forced on.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Bloom.swift`
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/FieldWash.swift`

## Verification

Previews with Reduce Transparency on show attenuated translucency; design-system tests stay green.
```

- [ ] **Step 6: Create `docs/todos/P2-dynamic-type-chrome.md`**

```markdown
---
priority: P2
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-2)
---

# Scale chrome/settings text with Dynamic Type

## Problem

`LumaFont.display/mono/ui` use `.custom(_:size:)` / `.system(size:)` with no `relativeTo:`, so no text scales with the user's content-size preference. `docs/rules/accessibility.md` requires chrome/settings/informational text to scale; the primary instrument readout may opt out deliberately.

## Fix

- Add a Dynamic-Type-scaling variant (`.custom(_:size:relativeTo:)` or `@ScaledMetric`) for `LumaFont.ui` and the mono readouts used in settings/account/chrome.
- Leave the large note/strobe readout fixed, with a comment documenting the deliberate opt-out.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaFont.swift`
- App settings/account/chrome views consuming `LumaFont.ui`

## Verification

Largest accessibility text size: settings/account text grows; note readout layout intact.
```

- [ ] **Step 7: Create `docs/todos/P2-contrast-color-independence.md`**

```markdown
---
priority: P2
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-3)
---

# WCAG AA contrast audit (both appearances) + honor differentiateWithoutColor

## Problem

No codified contrast budget exists, and `accessibilityDifferentiateWithoutColor` is unhandled. State is color-coded (mint/amber/blue); dark-first risks light-mode contrast being under-validated.

## Fix

- Measure state colors + text against WCAG AA (4.5:1 text / 3:1 graphics) in light AND dark; adjust tokens that fail.
- Read `@Environment(\.accessibilityDifferentiateWithoutColor)`; ensure any color-only affordance (e.g. compact/menu-bar state dot) gains a non-color cue when enabled.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaColor*`
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift`, menu-bar/compact state views

## Verification

Contrast ratios documented for both appearances; a `differentiateWithoutColor` preview shows the non-color cue.
```

- [ ] **Step 8: Create `docs/todos/P3-strobe-photosensitivity-check.md`**

```markdown
---
priority: P3
status: open
domain: accessibility
source: docs/audits/2026-06-18-patterns-vs-best-practices.md (C-4)
---

# Verify and record the strobe against WCAG 2.3.1 flash threshold

## Problem

The core feature is a strobe; `strobe.md` covers motion sensitivity but never the photosensitivity (flash) threshold. On-pitch it stands still; off-pitch it scrolls — likely safe, but unverified and unrecorded.

## Fix

- Analyze the off-pitch animation's flash rate × luminance-delta × screen-area against WCAG 2.3.1 ("three flashes or below threshold").
- Record the result (and any mitigation) as a one-line note in `docs/rules/strobe.md`.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/*` (animation params)
- `docs/rules/strobe.md` (record the check)

## Verification

Documented determination that the off-pitch animation is within the WCAG 2.3.1 threshold (or a mitigation if not).
```

- [ ] **Step 9: Create `.github/PULL_REQUEST_TEMPLATE.md`**

```markdown
## Summary

<!-- what & why -->

## Accessibility (delete rows that don't apply)
- [ ] Reduce Motion honored (ReducedGauge fallback where animated)
- [ ] Reduce Transparency honored (bloom / wash attenuated)
- [ ] Dynamic Type scales chrome/settings text (or opt-out documented)
- [ ] accessibilityLabel on interactive elements; live accessibilityValue on pitch views
- [ ] No color-only state; differentiateWithoutColor honored
- [ ] WCAG AA contrast in both light and dark
- [ ] (Strobe/animation) checked vs WCAG 2.3.1 flash threshold

## Security
- [ ] No networking outside LumaAPI; HTTPS only (no ATS exception)
- [ ] Secrets in Keychain (…ThisDeviceOnly), not UserDefaults/cache
- [ ] No PII/secrets in print/logs (os.Logger + .private)
```

- [ ] **Step 10: Verify todo filename/priority consistency**

Run:
```bash
for f in docs/todos/P*-*.md; do
  pre="${f##*/}"; pre="${pre%%-*}"
  fm="$(grep -m1 '^priority:' "$f" | awk '{print $2}')"
  [ "$pre" = "$fm" ] && echo "ok   $f ($fm)" || echo "MISMATCH $f: file=$pre frontmatter=$fm"
done
test -f .github/PULL_REQUEST_TEMPLATE.md && echo "PR template exists"
```
Expected: every new todo prints `ok …`; `PR template exists`.

- [ ] **Step 11: Commit**

```bash
git add docs/todos/_TEMPLATE.md docs/todos/P1-logging-oslogger-app.md docs/todos/P1-keychain-thisdeviceonly.md docs/todos/P2-account-delete-purge-verify.md docs/todos/P2-reduce-transparency.md docs/todos/P2-dynamic-type-chrome.md docs/todos/P2-contrast-color-independence.md docs/todos/P3-strobe-photosensitivity-check.md .github/PULL_REQUEST_TEMPLATE.md
git commit -m "docs: backlog todos for security/accessibility code fixes + PR checklist

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Create the shared invariant-patterns.sh library (single source of truth)

**Files:**
- Create: `scripts/lib/invariant-patterns.sh`
- Create: `.claude/hooks/tests/invariant-patterns.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces (sourced by Tasks 6 & 7):
  - `inv_check_file <abs_path>` → echoes zero or more lines, each `HARD:<path>:<line>: <msg>` or `REVIEW:<path>:<line>: <msg>`.
  - Individual checks: `inv_check_ats`, `inv_check_appending_component`, `inv_check_networking_scope` (HARD); `inv_check_print_in_app`, `inv_check_keychain` (REVIEW). Each takes one abs path, self-gates on type/location.

- [ ] **Step 1: Write the failing test `.claude/hooks/tests/invariant-patterns.test.sh`**

```bash
#!/bin/bash
# Tests for scripts/lib/invariant-patterns.sh — pure deterministic checks.
# Run:  bash .claude/hooks/tests/invariant-patterns.test.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
expect "print flagged"     "$(mk App/Engine/LiveTunerModel.swift 'print("[LUMA] hi")')" REVIEW 'print'
expect "debugPrint flagged" "$(mk App/Engine/X.swift 'debugPrint(thing)')" REVIEW 'print'
silent "fingerprint ok"    "$(mk App/Engine/Y.swift 'let fingerprint(x) = 1')"
silent "print in tests ok" "$(mk App/EngineTests/Z.swift 'print("[LUMA] hi")')"

# Keychain (REVIEW) — substring trap
expect "keychain bad"  "$(mk App/Account/KeychainStore.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlock')" REVIEW 'Keychain'
silent "keychain good" "$(mk App/Account/Good.swift 'add[k] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly')"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash .claude/hooks/tests/invariant-patterns.test.sh`
Expected: FAIL — `scripts/lib/invariant-patterns.sh` does not exist yet (source error / all cases fail).

- [ ] **Step 3: Write `scripts/lib/invariant-patterns.sh`**

```bash
#!/bin/bash
# Single source of truth for LUMA's deterministic security invariants.
# Sourced by .claude/hooks/validate-invariants.sh (per-file) and
# scripts/ci-invariants.sh (repo-wide). Each check takes ONE absolute path and
# echoes zero+ lines prefixed "HARD:" (blocks) or "REVIEW:" (advisory).
# Functions are pure and self-gate on file type/location.

inv_networking_allowed() {
  case "$1" in
    */App/Networking/*|*LumaAPI*|*AccountModel*|*TuningCardStore*|*GearStoreModel*|*/App/LumaApp.swift) return 0 ;;
    *) return 1 ;;
  esac
}

inv_is_app_production_swift() {
  case "$1" in *.swift) ;; *) return 1 ;; esac
  case "$1" in */App/*) ;; *) return 1 ;; esac
  case "$1" in *Tests/*|*Test.swift|*Tests.swift|*/Bench/*|*Benchmark*) return 1 ;; esac
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
  case "$1" in */App/Networking/*|*LumaAPI*) ;; *) return 0 ;; esac
  local hit; hit=$(inv_code_lines "$1" | grep -nE 'appending\(component:' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: appending(component:) percent-encodes slashes — use buildURL/appending(path:) for routes (docs/rules/security.md)"
}

# HARD: networking outside the LumaAPI allow-list
inv_check_networking_scope() {
  case "$1" in *.swift) ;; *) return 0 ;; esac
  case "$1" in */App/*) ;; *) return 0 ;; esac
  inv_networking_allowed "$1" && return 0
  local hit; hit=$(inv_code_lines "$1" | grep -nE '\b(URLSession|URLRequest)\b|^[[:space:]]*import[[:space:]]+Network\b' | head -1)
  [ -n "$hit" ] && echo "HARD:$1:${hit%%:*}: networking outside the LumaAPI layer — all backend calls go through LumaAPI (docs/rules/security.md)"
}

# REVIEW: print/debugPrint in App production code
inv_check_print_in_app() {
  inv_is_app_production_swift "$1" || return 0
  local hit; hit=$(inv_code_lines "$1" | grep -nE '\b(print|debugPrint)\(' | head -1)
  [ -n "$hit" ] && echo "REVIEW:$1:${hit%%:*}: print/debugPrint in App/ — use os.Logger with .private for PII/secret paths (docs/rules/security.md)"
}

# REVIEW: Keychain AfterFirstUnlock without ThisDeviceOnly (substring-trap safe)
inv_check_keychain() {
  case "$1" in *.swift) ;; *) return 0 ;; esac
  local hit; hit=$(inv_code_lines "$1" | grep -nE 'kSecAttrAccessibleAfterFirstUnlock' | grep -vE 'ThisDeviceOnly' | head -1)
  [ -n "$hit" ] && echo "REVIEW:$1:${hit%%:*}: Keychain AfterFirstUnlock without ThisDeviceOnly — backup-restore-eligible; prefer …AfterFirstUnlockThisDeviceOnly (docs/rules/security.md)"
}

# Run every check against one file.
inv_check_file() {
  inv_check_ats "$1"
  inv_check_appending_component "$1"
  inv_check_networking_scope "$1"
  inv_check_print_in_app "$1"
  inv_check_keychain "$1"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash .claude/hooks/tests/invariant-patterns.test.sh`
Expected: PASS — `N passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/invariant-patterns.sh .claude/hooks/tests/invariant-patterns.test.sh
git commit -m "feat(hooks): shared deterministic security-invariant check library

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Integrate the library into the local validate-invariants hook

**Files:**
- Modify: `.claude/hooks/validate-invariants.sh` (allow plist through; source the lib; remove the superseded inline App-networking REVIEW; route lib output)
- Modify: `.claude/hooks/tests/validate-invariants.test.sh` (add cases)

**Interfaces:**
- Consumes: `inv_check_file` from Task 5; `add_violation` / `add_review` already defined in the hook.

- [ ] **Step 1: Add the failing hook test cases**

Append these `run_case` lines to `.claude/hooks/tests/validate-invariants.test.sh` immediately before its final results/exit block (reusing the existing `make_file` / `run_case` helpers; HARD ⇒ exit 2/stderr, REVIEW ⇒ exit 0/stdout):

```bash
# --- security invariants (Task 6) ---
ATS=$(make_file "App/Info.plist" '<key>NSAllowsArbitraryLoads</key>' '<true/>')
run_case "ATS exception is HARD" Edit "$ATS" 2 stderr 'NSAllowsArbitraryLoads'

NETLEAK=$(make_file "App/Views/Leak.swift" 'import SwiftUI' 'let s = URLSession.shared')
run_case "networking leak is HARD" Edit "$NETLEAK" 2 stderr 'networking outside the LumaAPI'

PRINTF=$(make_file "App/Engine/Logy.swift" 'func f() { print("[LUMA] x") }')
run_case "print in App is REVIEW" Edit "$PRINTF" 0 stdout 'print/debugPrint'

KC=$(make_file "App/Account/KeychainStore.swift" 'let a = kSecAttrAccessibleAfterFirstUnlock')
run_case "keychain bare form is REVIEW" Edit "$KC" 0 stdout 'ThisDeviceOnly'

KCOK=$(make_file "App/Account/Good.swift" 'let a = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly')
run_case "keychain ThisDeviceOnly is clean" Edit "$KCOK" 0 none
```

- [ ] **Step 2: Run the hook tests to verify the new cases fail**

Run: `bash .claude/hooks/tests/validate-invariants.test.sh`
Expected: the five new cases FAIL (ATS file is skipped today because the hook early-exits on non-`.swift`; the security checks aren't wired yet).

- [ ] **Step 3: Allow `.plist` through the early-exit gate**

In `.claude/hooks/validate-invariants.sh`, replace the line:

```bash
[[ "$FILE_PATH" != *.swift ]] && exit 0
```

with:

```bash
case "$FILE_PATH" in *.swift|*.plist) ;; *) exit 0 ;; esac
```

- [ ] **Step 4: Source the shared library**

In `.claude/hooks/validate-invariants.sh`, immediately after the `PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"` line, add:

```bash
# shellcheck source=../../scripts/lib/invariant-patterns.sh
source "$PROJECT_DIR/scripts/lib/invariant-patterns.sh"
```

- [ ] **Step 5: Remove the superseded inline App-networking REVIEW block (and its now-unused helper)**

Delete this block:

```bash
# --- App layer: flag networking that has escaped the LumaAPI layer (soft) ---
if $is_app && ! networking_allowed "$FILE_PATH"; then
  hit=$(first_match_code '\b(URLSession|URLRequest)\b|^[[:space:]]*import[[:space:]]+Network\b')
  [ -n "$hit" ] && add_review "line ${hit%%:*}: networking outside the LumaAPI layer — confirm it belongs in App/Networking, not a view/model"
fi
```

And delete the now-orphaned helper (only that block used it):

```bash
# Files where backend networking is intentional (the opt-in monetization stack).
networking_allowed() {
  case "$1" in
    */App/Networking/*|*LumaAPI*|*AccountModel*|*TuningCardStore*|*GearStoreModel*|*/App/LumaApp.swift) return 0 ;;
    *) return 1 ;;
  esac
}
```

- [ ] **Step 6: Route the library output into the hook's two channels**

In `.claude/hooks/validate-invariants.sh`, immediately after the `add_review()` definition, add:

```bash
# Shared deterministic security invariants (single source of truth — also run in CI).
while IFS= read -r _inv; do
  [ -n "$_inv" ] || continue
  case "$_inv" in
    HARD:*)   add_violation "${_inv#HARD:}" ;;
    REVIEW:*) add_review    "${_inv#REVIEW:}" ;;
  esac
done < <(inv_check_file "$FILE_PATH")
```

- [ ] **Step 7: Run the hook tests to verify all pass**

Run: `bash .claude/hooks/tests/validate-invariants.test.sh`
Expected: PASS — all original cases plus the five new ones report `ok`.

- [ ] **Step 8: Commit**

```bash
git add .claude/hooks/validate-invariants.sh .claude/hooks/tests/validate-invariants.test.sh
git commit -m "feat(hooks): enforce security invariants in validate-invariants (HARD+REVIEW)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Create the CI invariants runner

**Files:**
- Create: `scripts/ci-invariants.sh`

**Interfaces:**
- Consumes: `inv_check_file` from Task 5.
- Produces: an executable that scans tracked `*.swift` + `*.plist`, prints HARD/REVIEW, exits nonzero iff any HARD. Task 8's CI job runs it.

- [ ] **Step 1: Write `scripts/ci-invariants.sh`**

```bash
#!/bin/bash
# Repo-wide security-invariant scan for CI. Exits nonzero on any HARD violation.
# REVIEW items are printed but never fail the build.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/invariant-patterns.sh"
cd "$PROJECT_DIR"

hard=0; review=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      HARD:*)   printf '✗ %s\n' "${line#HARD:$PROJECT_DIR/}" >&2; hard=$((hard+1)) ;;
      REVIEW:*) printf '• %s\n' "${line#REVIEW:$PROJECT_DIR/}";   review=$((review+1)) ;;
    esac
  done < <(inv_check_file "$PROJECT_DIR/$f")
done < <(git ls-files '*.swift' '*.plist')

echo ""
echo "Security invariants: ${hard} HARD, ${review} REVIEW"
if [ "$hard" -gt 0 ]; then echo "FAILED — HARD violations must be fixed." >&2; exit 1; fi
exit 0
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x scripts/ci-invariants.sh`

- [ ] **Step 3: Run against the current repo — MUST pass (the staged-gate baseline)**

Run: `./scripts/ci-invariants.sh; echo "exit=$?"`
Expected: `exit=0`. The summary should show `0 HARD` and a small number of REVIEW items (the existing `print` sites in `App/` and the current Keychain `AfterFirstUnlock`). If `hard > 0`, a "clean ✓" rule was mis-scoped — re-stage it to REVIEW in `invariant-patterns.sh` before proceeding.

- [ ] **Step 4: Sanity-check the failure path (temporary fixture, not committed)**

Run:
```bash
printf '<key>NSAllowsArbitraryLoads</key>\n<true/>\n' > /tmp/__ats_probe.plist
git add -n /tmp/__ats_probe.plist 2>/dev/null
# Library-level check (no commit needed):
source scripts/lib/invariant-patterns.sh; inv_check_file /tmp/__ats_probe.plist; rm -f /tmp/__ats_probe.plist
```
Expected: prints a `HARD:` ATS line — confirms the detector fires.

- [ ] **Step 5: Commit**

```bash
git add scripts/ci-invariants.sh
git commit -m "feat(ci): repo-wide security-invariant scanner (exits nonzero on HARD)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Add the CI invariants job

**Files:**
- Modify: `.github/workflows/ci.yml` (add `invariants` job)

**Interfaces:**
- Consumes: `scripts/ci-invariants.sh` from Task 7.

- [ ] **Step 1: Add the job under `jobs:` in `.github/workflows/ci.yml`**

Add as a sibling of the existing `engine` / `app` jobs:

```yaml
  invariants:
    name: Security invariants
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security invariant scan
        run: ./scripts/ci-invariants.sh
```

- [ ] **Step 2: Validate the workflow YAML parses**

Run:
```bash
python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); assert 'invariants' in d['jobs'], 'invariants job missing'; print('jobs:', list(d['jobs']))"
```
Expected: prints the jobs list including `invariants`; no exception.

- [ ] **Step 3: Re-run the scanner once more to confirm the gate is green at landing**

Run: `./scripts/ci-invariants.sh; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add security-invariants job (bash-only, parallel with engine/app)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- §2 deliverables 1–6 → Tasks 1 (rules), 2+3 (wiring), 5+6+7+8 (enforcement), 4 (PR template + todos + template enum), 2/5/6 (tests). ✓
- §3 rule content → Task 1 Steps 1–2 (verbatim). ✓
- §4 injection wiring (map, ranks, tags, CLAUDE.md, non-`.swift` injection) → Tasks 2–3. ✓
- §5 enforcement: SSOT lib (T5), staged gate (T5 severities + T7 baseline), CI job (T8), §5.4 grep cautions (T5 patterns: Keychain negative, `\b(print|debugPrint)\(`, scoped append). ✓
- §6 PR checklist → Task 4 Step 9. ✓
- §7 todos + template enum → Task 4. ✓
- §8 verification (validate-invariants cases, get_domains assertions, ci-invariants passes, injection smoke, existing tests) → T2 S5, T3 S4, T6 S7, T7 S3. ✓
- §9 out-of-scope (no app code) → enforced by Global Constraints. ✓

**2. Placeholder scan:** No TBD/TODO/"handle appropriately"; every code/test/command step shows complete content. ✓

**3. Type/name consistency:** `inv_check_file` and the five `inv_check_*` names + the `HARD:`/`REVIEW:` line format are defined in Task 5 and consumed identically in Tasks 6–7. `add_violation`/`add_review` match the existing hook. Solution `tags:` edits match the exact current strings captured from the repo. ✓

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-06-19-security-accessibility-governance.md`. Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session via executing-plans, batch execution with checkpoints.

Which approach?
