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
