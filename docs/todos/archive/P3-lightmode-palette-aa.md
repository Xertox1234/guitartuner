---
priority: P3
status: open
domain: design-system
source: docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md (sub-project 3 / C-3)
depends_on: docs/todos/archive/P2-contrast-color-independence.md
---

# Light-mode aurora state colors are below WCAG AA (deferred brand decision)

> **✅ COMPLETED 2026-06-21** — brand decision: **"two-tier" (keep ribbons vivid, make tag
> text readable).** Tag-text colorset tokens darkened to clear 4.5:1 (flat `#2E6BFF`→`#285EE2`
> 4.60, sharp `#D9760F`→`#9F5508` 4.62, inTune `#07A07C`→`#04775B` 4.59); strobe aurora light
> ribbons kept vivid, nudged only to clear 3:1 (sharp `#D9760F`→`#C66B0D` 3.16, tune
> `#07A07C`→`#069573` 3.14; flat unchanged at 3.74). `StateLine` now colours the in-tune tag
> from the text-safe `inTune` colorset (not the palette glow) for all states, making it
> palette-agnostic like FLAT/SHARP. Both `ContrastAuditTests` light tests re-enabled and
> passing. Full mechanism + before/after table: the **Resolution** section of
> `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`.
> **Scope:** aurora only — the four non-aurora palettes are tracked in
> `docs/todos/P3-lightmode-aa-other-palettes.md`.

## Problem

The C-3 contrast audit found the light-mode aurora state colors fall below WCAG AA
against the light background `#E7EAF1`:

| Token | Light ratio | Text (4.5:1) | Graphic (3:1) |
|-------|-------------|--------------|---------------|
| flat `#2E6BFF` | 3.74:1 | ❌ | ✅ |
| sharp `#D9760F` | 2.66:1 | ❌ | ❌ |
| inTune `#07A07C` | 2.76:1 | ❌ | ❌ |

Dark mode (the strobe tuner's primary appearance) passes everything (6.04 / 10.02 /
13.40). These are the signature brand colors and the "sacred" in-tune state, and a
hue-preserving fix is a *large* lightness change (sharp orange → deep brown, inTune
teal → dark teal), not a nudge — so it was deliberately **deferred** rather than
silently retuned.

**Decision (2026-06-20, product owner):** "document & defer." The C-3 work shipped
the audit + `@Test(.disabled(...))` markers on the two light-appearance contrast
tests (so CI is green and the gap is visible) and changed **no** token.

## Fix

Make the light-mode state colors meet AA — a brand/design decision, options:
- Hue-preserving lightness darkening of `flat`/`sharp`/`inTune` light variants to
  ≥ 4.5:1 (text) — accept the muted light palette; OR
- A targeted fix for the StateLine **tag text** only (darken its token usage / give
  it a darker treatment in light mode) while leaving the strobe ribbons vivid
  (the ribbons are graphics, audited separately at 3:1); OR
- A bespoke light-mode palette designed for AA from the start.

Then re-enable the two disabled tests in `ContrastAuditTests`
(`stateTextContrast_light`, `strobeGraphicContrast_light`) and update the audit doc.

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Resources/Colors.xcassets/{flat,sharp,inTune}.colorset/Contents.json`
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobePalette.swift` (aurora light chroma, if the strobe is retuned)
- `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift` (re-enable the disabled light tests)
- `docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`

## Verification

`ContrastAuditTests` light-appearance tests re-enabled and passing (≥ 4.5:1 text /
≥ 3:1 graphic), audit doc updated, brand sign-off recorded.
