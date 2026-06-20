# Sub-project 3 — Accessibility Code Conformance (Design)

**Date:** 2026-06-19
**Status:** approved — ready for implementation plan
**Source:** `docs/audits/2026-06-18-patterns-vs-best-practices.md` (C-1, C-2, C-3, C-4)
**Predecessor:** sub-project 1 (governance) — PR #50, merged `d2572b0` — *codified*
`docs/rules/accessibility.md` and stood up the REVIEW/HARD invariant machinery.
Sub-project 2 (security code conformance) — PR #51, merged `a2d682a` — made `App/`
conform to the security rules. This sub-project does the same for the four
accessibility rules, the way #2 did for security.

## Goal

Make `LumaDesignSystem` + `App/` code conform to the four accessibility rules
that `docs/rules/accessibility.md` **already mandates** (lines 7, 8, 10–11, 12),
then archive the four backlog todos. No rule *behaviour* changes — the rules
were codified in sub-project 1; the code has not yet caught up.

- **No rule changes.** `accessibility.md` already requires all four behaviours.
- **No gate promotion.** Unlike #2, there are no accessibility invariant gates to
  promote, and none are added — see "Gate promotion" below.
- **No strobe-palette retuning** beyond fixing a token that *fails* contrast; the
  strobe palette is the core visual and retuning it is a design decision, not a
  conformance fix.

## Background — what's already true

`docs/rules/accessibility.md` mandates (verified against current code, which does
**not** yet honor them — `grep` for `reduceTransparency`, `relativeTo:`,
`ScaledMetric`, `differentiateWithoutColor` across `Packages/` + `App/` returns
**zero** source matches):

- **Reduce Transparency** (line 7) — honor `accessibilityReduceTransparency`;
  attenuate `.bloom()` and `FieldWash` translucency.
- **Dynamic Type** (line 8) — chrome/settings/informational text scales via
  `relativeTo:` / `@ScaledMetric`; the primary instrument readout may opt out
  deliberately and commented.
- **Color independence** (line 10) — never signal state by color alone; honor
  `accessibilityDifferentiateWithoutColor`; preserve the existing redundancy.
- **Contrast** (line 11) — state colors + text meet WCAG AA (4.5:1 text / 3:1
  graphics) in **both** appearances; validate light explicitly.
- **Photosensitivity** (line 12) — the off-pitch strobe is verified against the
  WCAG 2.3.1 flash threshold; record the check in `strobe.md`.

All four findings already carry backlog todos, verified against current code in
this design:
- `docs/todos/P2-reduce-transparency.md` (C-1)
- `docs/todos/P2-dynamic-type-chrome.md` (C-2)
- `docs/todos/P2-contrast-color-independence.md` (C-3)
- `docs/todos/P3-strobe-photosensitivity-check.md` (C-4)

**Two staleness catches** (per the "todos go stale" rule):
1. The C-1 todo names only `Bloom.swift` / `FieldWash.swift`, but the
   *actually-shipped* wash is `ScreenBackground` (defined in `FieldWash.swift`,
   used at `App/LiveTunerScreen.swift:75`). `FieldWash` itself has no production
   call site. C-1 must cover `ScreenBackground`.
2. The C-4 todo (P3) frames the work as document-only ("analyze, conclude it's
   probably fine, write a one-line note"). That framing is too weak — see C-4.

## The verification model

These findings are mostly **not** naturally unit-testable, and the task-reviewer
rubric flags a test that asserts nothing as a defect. Each task therefore
declares its *real* verification up front; the plan must **not** manufacture
hollow asserts to satisfy a TDD template.

| Finding | Real verification |
|---------|-------------------|
| **C-1** | Extract the attenuation into a **pure helper** → unit-assert `attenuated < base`; plus `#Preview`s (dark + light) with `accessibilityReduceTransparency` forced on |
| **C-2** | **Previews** at the largest accessibility size (dark + light) + code review that the scaling APIs are wired (chrome opts in, instrument opts out) + the doc-comment fix. **No headless unit assertion is achievable**: a SwiftUI `Font` is opaque (no public API resolves it to a point size), `@ScaledMetric` only scales inside a view's environment, and `UIFontMetrics.scaledValue(for:)` is **iOS-only** while the DS package's `swift test` builds for **macOS** — so previews + review are the honest verification here, not a hollow assert |
| **C-3** | **Documented** contrast ratios (a measurement, not an assertion) + `differentiateWithoutColor` preview + a genuine **StringRow VoiceOver-label** assertion |
| **C-4** | An **analysis writeup**; *if* the mitigation branch fires → a unit-assert on the `StrobeMath` rate/luminance clamp |

## Acceptance gate

- `swift test --package-path Packages/LumaDesignSystem` green (most work lives
  here; the new C-1/C-2/C-3 unit tests run here).
- `xcodebuild build` macOS + iOS green (C-2 touches `App/` chrome consumers).
- Each finding's declared verification (above) is satisfied.
- The four todos are `git mv`'d to `docs/todos/archive/`.

## Scope — four work items

### C-1 — Reduce Transparency

Honor `@Environment(\.accessibilityReduceTransparency)` in the translucency
sources:
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/Bloom.swift` —
  additive glow via stacked `.shadow` layers at fixed opacities.
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Modifiers/FieldWash.swift`
  — both the `FieldWash` radial and **`ScreenBackground`** (the shipped wash).

When the trait is on, attenuate bloom opacities/radii and wash opacity (or
substitute a solid treatment) so legibility is preserved without translucency.

**Design for testability:** extract the attenuation into a **pure function** —
e.g. `f(baseOpacity, reduceTransparency: Bool) -> Double` — so the rule
("attenuated < base when the trait is on") is a real unit assertion, and the
modifiers stay thin. Add `#Preview`s in dark and light with the trait forced on.

### C-2 — Dynamic Type

`Packages/LumaDesignSystem/Sources/LumaDesignSystem/Tokens/LumaFont.swift`
builds every font from a fixed point size (`.custom(_:size:)` / `.system(size:)`)
with no `relativeTo:` and no `@ScaledMetric` anywhere — so nothing scales with the
user's content-size preference.

- **Chrome / settings / account text scales.** Mechanism: add `relativeTo:`
  text-style anchoring to the custom-font builders (`display`, `mono`); use
  `@ScaledMetric` for the system-font `ui(_:)` path (a fixed-size `.system`
  font cannot scale via `relativeTo:`). The implementer picks the exact API
  shape; the requirement is that `LumaFont.ui` and the chrome mono readouts
  scale.
- **The instrument readout opts out, commented.** The large note/cents/strobe
  readout (`NoteReadout`, `CentsReadout`, `StageView`) stays fixed-size by
  deliberate, commented choice (a full-bleed instrument).
- **Fix the doc-vs-code lie.** `ui(_:)`'s doc comment currently claims "full
  Dynamic Type + localization" while delivering neither — make the comment true
  (it now scales) or correct it; do not leave the false claim.

Chrome consumers to migrate (verified call sites): `App/SettingsView.swift`,
`App/Views/Monetization/{AccountSheet,GearStoreScreen,SaveCardSheet}.swift`,
`App/MenuBarTuner.swift`, and the DS chrome components
(`Brand`, `A4Control`, `EdgeButton`, `TargetChip`, `FreqLine`). Instrument-readout
consumers (`NoteReadout`, `CentsReadout`, `StateLine`, `StringRow`, `StageView`,
the `LiveTunerScreen` dock readouts) are the deliberate opt-out.

**Verification reality:** C-2 has no headless unit test (see the verification
table — `Font` is opaque, `UIFontMetrics` is iOS-only, the host test target is
macOS). Verification is previews at the largest accessibility size + code review
that the builders use the scaling APIs and the opt-out is explicit. The
cross-platform-correct mechanism choice (custom vs. system path, `relativeTo:`
vs. `@ScaledMetric`) is the subtlest single decision in the sub-project — this
task gets the **most-capable model**, not the standard tier.

### C-3 — Contrast audit + color independence

Mostly *verify + document + a small residual* (the shape B-4 had in #2).

**Part 1 — contrast audit (explicit fg/bg pairings).** Measure the six
asset-catalog state colors —
`Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Colors.xcassets/{inTune,inTune2,sharp,sharp2,flat,flat2}.colorset`
— against the **actual app background tokens** the state text/UI is shown over in
each appearance (the implementer resolves the exact bg token per surface — the
strobe's near-black `≈ #0A0B10` is a *separate* palette, see below) for WCAG AA
(4.5:1 text). Document the ratios for **both** appearances.

**Adjusting a failing token is a design decision — treat both color sources the
same way.** If an asset-catalog state color fails, the implementer applies only a
**hue-preserving lightness change** (minimal, documented); any adjustment that
would shift the brand hue is **surfaced to the user**, not made silently. The
strobe's **separate** literal-RGB palette (`Strobe/StrobePalette.swift`) is
audited identically at 3:1 graphics and documented under the same rule — audit +
document, no silent retune of the core visual.

**Part 2 — color independence.** `accessibilityDifferentiateWithoutColor` is read
nowhere. The primary flow already honors "never color alone" (StateLine text tag,
CentsReadout sign + arrow glyph, menu-bar note text), so honoring the trait is
largely defensive. The one real residual:
`Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StringRow.swift`
conveys the in-tune lock state by color + scale only and **omits it from the
VoiceOver label** (`accessibilityLabel("String …, …")`). Fix the label to
announce the lock/in-tune state (a genuine, testable assertion) and add a
`differentiateWithoutColor` preview showing a non-color cue where state is shown.

*(Folding the StringRow VoiceOver fix here rather than opening B-5: it is a
color-state residual, in scope for C-3; broad B-5 VoiceOver is already broadly
implemented and stays out of scope.)*

### C-4 — Photosensitivity (analysis-gated, sequenced last)

WCAG 2.3.1 (flashing) is **Level A** and applies to the **default** experience —
the existing Reduce Motion → `ReducedGauge` opt-out does **not** discharge it.
The production strobe is **phase-driven**: off-pitch flash/cycle rate tracks the
acoustic beat frequency and is **unbounded** (can exceed 3 Hz), full-screen, high
luminance delta (bright additive ribbons on near-black). The traveling-wave
nature (out-of-phase regions reduce the *concurrently* flashing area) is what may
save it, but with ~13 ribbons that is not self-evidently safe.

**Analysis-gated, two branches — do not pre-commit:**
1. **Rigorous measurement:** beat-rate range × concurrent bright-area fraction ×
   luminance delta, against ">3 opposing luminance reversals/sec over >~25% of
   the central visual field."
2. **Below threshold** → record the determination as the one-line note
   `strobe.md` already mandates (line 12 of `accessibility.md`).
3. **At/above threshold** → add a **default-mode** mitigation: clamp the
   effective flash rate (cap scroll/rotation velocity so per-pixel flicker ≤
   threshold) and/or clamp luminance delta when the beat rate is high. This
   touches `Strobe/StrobeMath.swift` and the four renderers — including the
   **Metal shaders** (`MetalStrobe.swift`, `RadialMetalStrobe.swift`).

**Decompose into two plan tasks** (the analysis result gates whether code is
written — this does not fit one TDD task):
- **4a — analysis.** Produce the determination writeup (the measurement above).
  The controller reads it and decides whether 4b is dispatched. If "below
  threshold," 4a also lands the one-line `strobe.md` note and C-4 ends here.
- **4b — conditional mitigation.** Dispatched **only if** 4a finds a hazard.
  Implements the rate/luminance clamp.

**Risk controls (CLAUDE.md):** the mitigation branch is Metal-shader / strobe
work — **most-capable model**, **strobe-specialist review**, never delegated to a
cheap worker. Sequenced **last** so its uncertainty does not block C-1/C-2/C-3.
The clamp logic lands in `StrobeMath` (pure) so it carries a unit assertion
(clamped velocity ≤ cap).

## Gate promotion — none applies (a finding, not work)

`scripts/lib/invariant-patterns.sh` is **security-only** (its header says so);
there are no accessibility REVIEW gates to promote, unlike sub-project 2. And
accessibility conformance cannot be reliably grep-gated — you cannot grep
"missing `accessibilityValue`" or "translucency that ignores Reduce
Transparency" without high false-positive rates. Sub-project 3 therefore adds
**no** invariant gates; this conformance is enforced by the rules + code review.
Recorded here so the absence is a decision, not an oversight.

## Sequencing & process

- **Branch first** — done: `accessibility-code-conformance` off `main` (`a2d682a`).
- Task order **C-1 → C-2 → C-3 → C-4 → wrap-up**: deterministic wins first,
  C-4's analysis uncertainty last.
- Execution via subagent-driven-development (same as #2). Task order
  **C-1 → C-2 → C-3 → C-4a → (C-4b if needed) → wrap-up**. Model selection:
  C-1/C-3 standard tier; **C-2 most-capable** (the cross-platform font-scaling
  mechanism is the subtlest single decision); **C-4 most-capable** (analysis +
  possible Metal mitigation) with strobe-specialist review; final whole-branch
  review most-capable.
- On completion, `git mv` the four todos
  (`P2-reduce-transparency`, `P2-dynamic-type-chrome`,
  `P2-contrast-color-independence`, `P3-strobe-photosensitivity-check`) into
  `docs/todos/archive/`.
- **Transparency at the seam:** if C-4 lands as document-only, the PR body and the
  archived `P3-strobe-photosensitivity-check` note must state plainly that the
  determination was "within threshold → documented, no code mitigation," with the
  measured numbers — so a "no code changed" outcome reads as a verified decision,
  not a skipped task. If C-3 finds all contrast tokens already pass, same rule:
  document the ratios and say so.

## Verification

- `swift test --package-path Packages/LumaDesignSystem` — the new C-1/C-2/C-3
  (and any C-4 clamp) unit tests + existing DS tests, all green.
- `xcodebuild build -project LUMA.xcodeproj -scheme LUMA -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`
  and `… -destination 'generic/platform=iOS Simulator' …` — C-2's `App/` chrome
  migration compiles on both platforms.
- `#Preview`s (C-1 dark/light trait-on, C-2 largest accessibility size, C-3
  `differentiateWithoutColor`) demonstrate the visual behaviours.
- `swift test --package-path Packages/TunerEngine` — unaffected, must stay green.
- `./scripts/ci-invariants.sh` — still 0 HARD / 0 REVIEW (no security regressions).

## Out of scope

- B-5 broad VoiceOver — already broadly implemented; only the StringRow
  color-state residual is folded into C-3.
- The security findings (A-1, B-1, B-2, B-3, B-4) — done in sub-projects 1–2.
- Strobe-palette retuning beyond a contrast-failing-token fix (C-3).
- Adding accessibility invariant gates — high false-positive, YAGNI (see "Gate
  promotion").
