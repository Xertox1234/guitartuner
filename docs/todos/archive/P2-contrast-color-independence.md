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

## Resolution (2026-06-19, sub-project 3 / C-3)

Resolved in commits `77f95af` + `23b5e75` + `ba6535a`. Added a test-only WCAG sRGB
luminance/ratio audit (`ContrastAuditTests`) pinning the design tokens, split by
USAGE: state-colored **text** (StateLine tag, 10pt → 4.5:1) and strobe **graphic**
/ large numerals (→ 3:1), each dark + light. Audit doc:
`docs/solutions/accessibility/state-color-contrast-audit-2026-06-19.md`. Honored
`differentiateWithoutColor` in `StringRow` via a pure testable
`StringCell.a11yLabel(...)` (announces lock/active state, not color-only) + a
checkmark cue (2 `StringRowA11yTests`).

**Outcome / deviation (decided with the product owner):** dark mode (the strobe
tuner's primary appearance) meets AA throughout. **Light mode is below AA** —
flat 3.74, sharp 2.66, inTune 2.76 vs bg `#E7EAF1` (all < 4.5 text; sharp/inTune
also < 3.0 graphic). These are the signature brand colors and the fixes are large
(not nudges), so per the spec's surface-don't-silently-retune policy the user chose
**"document & defer"**: NO token was changed; the two light-appearance tests are
`@Test(.disabled(...))` with surface reasons so CI stays green and the gap stays
visible. Follow-up tracked in `docs/todos/P3-lightmode-palette-aa.md`.
