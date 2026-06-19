---
scope: patterns-vs-best-practices
date: 2026-06-18
status: report-no-code-changes
subject: docs/rules/*.md + docs/solutions/**.md
axes: [security, accessibility]
finding_count: 10
finding_breakdown: { tier_A_pattern_endorses_below_bar: 1, tier_B_codification_gap: 5, tier_C_true_gap: 4 }
---

# LUMA — Collected Patterns vs. Security & Accessibility Best Practices

**Goal:** Validate the *codified patterns* (`docs/rules/`, `docs/solutions/`) against common
security and accessibility best practices. **This is a report only — no code was changed.**

## What this is (and is not)

The subject under review is **the pattern set**, not the codebase. `docs/audits/` already holds
five full code audits (the 2026-06-15 sweep alone has 34 findings). This report does **not**
re-audit the code. It asks one question the prior audits did not: *do the collected rules and
solutions hold up against security/accessibility best practice, and what do they fail to govern?*

Code was inspected only as **ground truth** — to tell apart "the pattern is silent but the code is
already correct" from "the pattern is silent and the code is also missing it."

## Method

- Read all 7 `docs/rules/*.md` and all 11 `docs/solutions/**.md` entries.
- Mapped every security- or accessibility-relevant pattern to the corresponding best practice
  (Apple HIG accessibility, Apple platform security / Keychain guidance, OWASP MASVS-STORAGE,
  Apple privacy-manifest requirements, WCAG 2.x: 1.4.1, 1.4.3/1.4.4, 2.3.1).
- Verified each claim against source: `App/PrivacyInfo.xcprivacy`, `App/Account/KeychainStore.swift`,
  `Packages/LumaDesignSystem/.../Tokens/LumaFont.swift`, `Packages/.../Strobe/StrobeField.swift`,
  and targeted greps for `differentiateWithoutColor`, `reduceTransparency`, `relativeTo:`,
  `NSAppTransportSecurity`, Keychain accessibility class.

## How to read the findings — the three tiers

Findings are ranked by how the *pattern* relates to best practice, not by raw severity:

| Tier | Meaning | Why it matters |
|------|---------|----------------|
| **A — Pattern endorses below-bar practice** | A rule/solution actively tells you to do the weaker thing | Strongest: the pattern points the wrong way; following it propagates the weakness |
| **B — Codification gap** | Best practice is followed in code, but no pattern protects it | Regression risk: nothing stops a future change from undoing it; add a pattern |
| **C — True gap** | Best practice is absent from both patterns *and* code | Net-new work; flagged here for the backlog |

---

## Security

### A-1 — `swiftui.md` codifies `print("[LUMA] …")` as the logging convention (Tier A) ★ headline

**Pattern:** `docs/rules/swiftui.md` and
`docs/solutions/runtime-errors/application-support-not-created-…md` both *prescribe*
`print("[LUMA] …")` for recoverable-path failures, the latter explicitly justifying it with
"there is no `os.Logger` in `App/`."

**Why it's below the bar.** LUMA's `App/` layer handles an email address (`PrivacyInfo.xcprivacy`
declares `NSPrivacyCollectedDataTypeEmailAddress`, linked) and auth/refresh tokens
(`KeychainStore`). The codified pattern logs raw error objects (`\(error)`) on the network and
cache paths — error values routinely carry URLs, server responses, and account context.

- `print` writes to **stderr**. It offers **no privacy redaction** and no structured/leveled
  logging — output handling is uncontrolled.
- `os.Logger` provides per-interpolation redaction (`\(value, privacy: .private)`) and structured
  levels — the right tool when any logged value may carry PII or secrets.
- **In-repo precedent already exists:** `Packages/LumaDesignSystem/.../Fonts/LumaFonts.swift` uses
  `os.Logger` with an explicit `privacy:` qualifier. Only `App/` — the layer that touches PII —
  uses `print`.

**Recommendation (doc/pattern change, not a code mandate here):** revise the two patterns to
prescribe `os.Logger` in `App/` with `.private` on any interpolated error/PII, and demote `print`
to a non-prescribed fallback. This is the one finding where the pattern itself, if followed,
spreads the weaker practice.

### B-1 — Token storage at rest is uncodified; chosen Keychain class is backup-eligible (Tier B)

**Code (ground truth):** `App/Account/KeychainStore.swift` stores tokens with
`kSecAttrAccessibleAfterFirstUnlock`. There is **no** codified pattern anywhere governing token
storage, Keychain usage, or credential lifecycle.

**Assessment.** Using the Keychain (not `UserDefaults`/JSON cache) for tokens is correct, and
`AfterFirstUnlock` is the right *availability* class for background token refresh. The precise
gap: it is **not** the `…ThisDeviceOnly` variant, so the credential is **eligible to migrate to a
new device via an encrypted backup restore**.

- To be precise about the mechanism: this does **not** sync via iCloud Keychain — that would
  require `kSecAttrSynchronizable`, which is **not set** here. The exposure is restore-migration,
  not live cross-device sync.
- Best practice for bearer credentials (OWASP MASVS-STORAGE; Apple guidance) favors
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — **same availability** (background refresh
  still works), but the secret never leaves the device through a backup.

**Recommendation:** codify a "tokens live in Keychain, `…ThisDeviceOnly`, never in
`UserDefaults`/cache" pattern; consider the `ThisDeviceOnly` class for the token entries.

### B-2 — ATS is enforced only by default; no pattern requires it (Tier B)

**Code:** no `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` key in `App/Info.plist` →
App Transport Security defaults apply → HTTPS + TLS 1.2+ enforced for `LumaAPI`. Good.

**Gap:** the secure state is *implicit*. No pattern requires HTTPS/ATS for `LumaAPI`, so a future
"just let me hit the dev server over HTTP" change adding `NSAllowsArbitraryLoads` would pass every
existing rule. The `swiftui.md` networking rule governs *where* networking lives (`LumaAPI` only),
not *how* it must be secured.

**Recommendation:** add a one-line pattern: "`LumaAPI` is HTTPS-only; do not add ATS exceptions."
Certificate pinning is optional hardening, not required — note it as a deliberate non-goal so its
absence is a decision, not an oversight.

### B-3 — "v1 collects nothing" vs. the email in the privacy manifest — scope the claim (Tier B)

**Patterns:** `CLAUDE.md` ("Privacy by architecture: on-device only, v1 collects nothing") and the
capture/swiftui rules ("Audio … never recorded, stored, or transmitted").

**Assessment — this is scoping precision, not a contradiction.** The **audio** privacy guarantee
is sound and genuinely architectural (`TunerEngine` has no networking). The blanket phrase
"collects nothing," however, is broader than what now ships: `PrivacyInfo.xcprivacy` correctly
declares `EmailAddress` collected (linked, app-functionality, non-tracking) via the opt-in account
stack. The manifest is **right**; the tagline is **stale relative to the monetization stack**.

**Recommendation:** tighten the codified claim to its true scope — "audio never leaves the device;
no account is required to tune; the optional account collects only email, as declared in the
privacy manifest." Avoids an App-Store-review or marketing-claim mismatch.

### B-4 — Account-data lifecycle (deletion/retention) is implemented but uncodified (Tier B)

**Code:** an account-deletion path is referenced in `App/Account/AccountModel.swift` and surfaced
in `App/Views/Monetization/BottomDrawer.swift` — so the App Store requirement for account-creating
apps (in-app account deletion) appears **met**.

**Gap:** no pattern governs account-data handling — deletion guarantees, what Keychain/cache state
must be purged on sign-out vs. delete, or retention. This is exactly the kind of cross-cutting
invariant the `solutions/` set exists to protect, and it's the one privacy-relevant flow with
nothing written down.

**Recommendation:** codify a short "account lifecycle" solution: delete must clear Keychain tokens
+ any cached account JSON; sign-out vs. delete differ; email is the only collected datum.

---

## Accessibility

### B-5 — VoiceOver is broadly implemented but no pattern requires it (Tier B)

**Code:** `accessibilityLabel`/`accessibilityValue` appear across ~16 components and all strobe
renderers (`AuroraStrobe`, `RadialMetalStrobe`, `MetalStrobe`, `ReducedGauge`) plus
`LiveTunerScreen`/`SettingsView`. For a Metal-rendered instrument this is strong, credit-worthy
work.

**Gap:** none of `strobe.md`, `design-system.md`, or `swiftui.md` mentions VoiceOver,
accessibility labels, or — most importantly for a tuner — a **live `accessibilityValue` /
announcement of pitch state** ("in tune", signed cents) so a blind user gets the reading the
strobe conveys visually. The design-system rule "every new component requires `#Preview`s" has no
accessibility analog, so a new component can ship label-less and pass every rule.

**Recommendation:** add to `design-system.md`/`strobe.md`: interactive/stateful components require
an `accessibilityLabel`, and pitch-bearing views expose a live `accessibilityValue`.

### C-1 — Reduce Motion is the model to copy — but Reduce Transparency is not honored (Tier C)

**Strong (credit):** `strobe.md` codifies honoring `@Environment(\.accessibilityReduceMotion)` and
substituting `ReducedGauge` ("do not just slow the animation"), and `StrobeField.swift` implements
it. This is the **best-aligned pattern in the set** — keep it as the template for the rest.

**Gap (Tier C — pattern silent, code silent):** the companion setting **Reduce Transparency** is
honored nowhere (`grep` for `reduceTransparency` → none), yet the design language leans hard on
translucency — `Bloom.swift` (additive bloom) and `FieldWash.swift`. `design-system.md` mandates
"glow via additive bloom, never drop-shadows" but never says to attenuate it under Reduce
Transparency. Apple HIG asks apps to reduce blur/translucency when this is on.

**Recommendation:** extend the strobe/design-system rules to honor Reduce Transparency the same way
Reduce Motion is honored (attenuate bloom/wash, don't just keep it).

### C-2 — Dynamic Type: secondary/chrome text does not scale (Tier C)

**Code (verified):** `LumaFont.display/mono/ui` resolve via `.custom(family, size:)` /
`.system(size:)` with **no `relativeTo:` parameter anywhere** — so no text scales with the user's
preferred content size. `design-system.md` mandates tabular digits (good, prevents jitter) but is
silent on Dynamic Type.

**Nuanced assessment (not a blanket flag):**
- The **primary visualization** — large note readout, strobe field — is a full-bleed instrument;
  fixed sizing there is a defensible deliberate choice.
- The real finding is **secondary/informational and chrome text** (settings, account sheet, state
  hints via `LumaFont.ui`): this *should* scale via `.custom(_:size:relativeTo:)` /
  `@ScaledMetric`, and currently cannot. That fails Apple Dynamic Type expectations and WCAG 1.4.4
  (resize text) for the text-bearing UI.

**Recommendation:** codify "chrome/settings/account text uses a Dynamic-Type-scaling font
(`relativeTo:`/`@ScaledMetric`); the primary instrument readout may opt out deliberately." Make the
opt-out explicit so it's a decision, not an accident.

### C-3 — Use-of-color: `differentiateWithoutColor` unhandled; no contrast rule (Tier C)

**Code:** state is color-coded — `LumaColor.tune` (mint) / `.sharp` (amber) / `.flat` (blue).
`@Environment(\.accessibilityDifferentiateWithoutColor)` is honored **nowhere** (grep → none).

**Mitigating context (keep this — it softens the finding):** the live tuner already carries
**non-color** redundancy — `StateLine` renders a textual state, the strobe **scroll direction**
encodes sharp vs. flat, and the **signed cents** number is explicit. So this is not a pure
color-only signal (WCAG 1.4.1 is largely satisfied by the redundant cues in the main flow).

**Two genuine gaps remain:**
1. `design-system.md`'s "do not introduce new state colors without explicit design decision"
   governs *consistency*, not *contrast* — there is **no codified WCAG 1.4.3 contrast requirement**
   (AA: 4.5:1 text / 3:1 graphics). Combined with the "dark-first, light mode secondary" rule,
   light-mode contrast is structurally under-validated.
2. The named iOS setting (`differentiateWithoutColor`) isn't honored, so any place that *does* rely
   on color alone (e.g. a compact/menu-bar state dot) has no fallback.

**Recommendation:** add a contrast budget to `design-system.md` (AA ratios, validated in both
appearances) and a rule to honor `differentiateWithoutColor` wherever state is shown by color
without text.

### C-4 — Photosensitivity (WCAG 2.3.1) is unconsidered in the strobe patterns (Tier C)

**Observation:** the product's core is a **strobe**. `strobe.md` thoroughly addresses *motion*
sensitivity (Reduce Motion → `ReducedGauge`) but **Reduce Motion ≠ photosensitivity protection**.
There is no codified consideration of flash rate or large-area luminance change against WCAG 2.3.1
("three flashes or below threshold").

**This is a verify item, not an asserted defect.** On-pitch the strobe stands still; off-pitch it
*scrolls* (translation ≠ flash), and a scrolling gradient is unlikely to breach the flash
threshold. But the mechanism has never been checked or written down, and "strobe" is precisely the
feature where a reviewer expects it to have been.

**Recommendation:** add a one-line note to `strobe.md` recording that the off-pitch animation was
checked against the WCAG 2.3.1 flash threshold (rate × luminance-delta × screen area), so the
absence of a flash hazard is a documented decision.

---

## What's already strong (keep as templates)

- **Reduce Motion handling** (`strobe.md` + `StrobeField`) — exemplary; the model for the Reduce
  Transparency and Dynamic Type gaps above.
- **Audio privacy is genuinely architectural** — `TunerEngine` has no networking; "audio never
  leaves the device" is enforced by structure, not convention. Best-in-class.
- **Recoverable-path robustness** — "never `assertionFailure`/`fatalError` on cache/network/decode
  paths" (`swiftui.md` + the Application-Support solution) is sound availability hygiene; the only
  fix needed is the *logging mechanism* it prescribes (A-1), not the principle.
- **URL-construction safety** (`appending(path:)` not `component:`, regression-tested) correctly
  protects the Sign-in-with-Apple route — a real correctness/auth-flow guard.
- **Keychain is used for tokens at all** (B-1) — the storage location is right; only the class and
  the missing pattern need attention.
- **Privacy manifest exists and is accurate** — declares email + the `UserDefaults` required-reason
  (`CA92.1`), `NSPrivacyTracking false`. Ahead of many apps.

## Out of scope (reviewed, no security/accessibility bearing)

The DSP/pipeline/strobe-performance patterns — `dsp.md`, `pipeline.md`, `testing.md`, the
harmonic-estimator / phase-integrator / vDSP-zero-delta / metal-triple-buffer / clock-correction
solutions — are correctness, accuracy, and rendering-performance patterns. They were read in full;
none bears on security or accessibility and none conflicts with either. (The Metal triple-buffer
deadlock-safety solution is *reliability*, adjacent to but not an accessibility concern.)

## Consolidated recommendations (all documentation/pattern changes — no code in this task)

| # | Tier | Pattern to change | Change |
|---|------|-------------------|--------|
| A-1 | A | `swiftui.md`, app-support solution | Prescribe `os.Logger` + `.private` in `App/`; demote `print` |
| B-1 | B | *(new)* token-storage rule | Keychain only, `…ThisDeviceOnly`; never `UserDefaults`/cache |
| B-2 | B | `swiftui.md` networking rule | `LumaAPI` is HTTPS-only; no ATS exceptions |
| B-3 | B | `CLAUDE.md` privacy claim | Scope "collects nothing" → audio + no-account default; email via opt-in |
| B-4 | B | *(new)* account-lifecycle solution | Delete purges tokens+cache; retention; email is sole datum |
| B-5 | B | `design-system.md` / `strobe.md` | Stateful components need labels; pitch views need live `accessibilityValue` |
| C-1 | C | `strobe.md` / `design-system.md` | Honor Reduce Transparency (attenuate bloom/wash) |
| C-2 | C | `design-system.md` | Chrome/settings text scales (`relativeTo:`); instrument may opt out explicitly |
| C-3 | C | `design-system.md` | WCAG AA contrast budget (both appearances); honor `differentiateWithoutColor` |
| C-4 | C | `strobe.md` | Record WCAG 2.3.1 flash-threshold check for off-pitch animation |

*Each row is a candidate `/codify` entry or `docs/todos/` item; none modifies shipping code, per
the scope of this report.*
