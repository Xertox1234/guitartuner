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

## Resolution (2026-06-19, sub-project 3 / C-1)

Resolved in commit `6b22ce8`. Added a pure SwiftUI-free policy helper
`enum Translucency { static func attenuated(_ base: Double, reduceTransparency: Bool) -> Double }`
(returns 0 when the trait is on) and routed every bloom shadow + wash opacity
through it, gated on `@Environment(\.accessibilityReduceTransparency)`. Unit-tested
(`TranslucencyTests`).

**Scope note:** covered `Bloom`, `FieldWash`, AND `ScreenBackground` (the shipped
ambient-glow wash) — the todo named only `FieldWash`. In `ScreenBackground` only
the translucent glow wash is attenuated; the opaque base canvas gradient is kept
so legibility holds.

**SDK note:** the forced-trait previews were kept but the
`.environment(\.accessibilityReduceTransparency, true)` line was dropped — that env
key is **get-only** under the current SDK and won't compile; verify via
Accessibility Inspector (the unit test is the correctness gate).
