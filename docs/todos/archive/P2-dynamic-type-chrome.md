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

## Resolution (2026-06-19, sub-project 3 / C-2)

Resolved in commits `e3e1901` + `a1277cc`. Added optional `relativeTo:` to
`LumaFont.display/mono` (custom fonts) and a `@ScaledMetric`-backed
`View.lumaUIFont(_:weight:relativeTo:)` for system chrome (a system font cannot
carry `relativeTo:`). Migrated all chrome/settings/account/store call sites; the
`ui()` doc-comment lie was corrected.

**Opt-out** is exactly the large instrument numerals — `lumaNote` (168) + the
accidental, and `lumaCents` (30) — each commented; the octave / ¢ satellites scale.
Verified via an AX5 gallery preview (`\.dynamicTypeSize` IS writable) + macOS & iOS
builds + review. Review fix (`a1277cc`): two decorative GearStore SF-Symbol glyphs
in fixed frames were reverted to a fixed font (they would clip at AX5).

**Related:** see the separate todo `P2-system-fonts-monetization.md` — re-verify it
against the now-migrated monetization views (may be wholly/partly resolved here).
