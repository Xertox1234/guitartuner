---
severity: low
audit: 2026-06-12-full
finding: L1
---

# L1 — Spring Animation in `StringRow` Doesn't Watch `locked`

`scaleEffect(active || locked ? 1.0 : 0.95)` computes scale from both `active` and `locked`,
but `.animation(.spring(...), value: active)` only re-evaluates on `active` changes.
A `locked` transition on a non-active cell would snap without animation (latent — current
`lockedIdx == activeIdx` invariant prevents it today).

**File:** `LumaDesignSystem/Components/StringRow.swift` (lines 85–86)

**Fix:** `.animation(.spring(response: 0.28, dampingFraction: 0.52), value: active || locked)`
