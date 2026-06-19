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
