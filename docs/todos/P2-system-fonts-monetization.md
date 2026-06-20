---
priority: P2
status: open
domain: swiftui
source: 2026-06-15-full audit (M6)
---

# System fonts used in monetization screens instead of LumaFont tokens

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

Monetization screens should use `LumaFont.display` / `LumaFont.mono` (via `.lumaUIFont(_:)`)
instead of system text styles (`.caption`, `.subheadline`, `.headline`, `.footnote`,
`.title2/3`, `.caption2`). Design token compliance is required across all screens, not only
the tuner UI.

**Rescoped 2026-06-20 (verification):** the four originally-named files are now **clean** —
`AccountSheet.swift`, `GearStoreScreen.swift`, `SaveCardSheet.swift` carry **0** system-font
usages (converted to `LumaFont` / `.lumaUIFont`), and `SettingsView.swift` is no longer under
`Monetization/` (it lives at `App/SettingsView.swift`, also clean). The violation did **not**
go away — it moved: `BottomDrawer.swift` (a newer file not in the original audit) now has
**12** system-font usages. This todo is rescoped to that file rather than closed.

## Fix

- Replace the 12 system-font references in `BottomDrawer.swift` with equivalent `LumaFont`
  tokens (`.lumaUIFont(LumaFont.Size.cap)` for `.caption/.caption2`, `LumaFont.display(...)`
  for `.title3/.subheadline`), matching the pattern already used in the now-clean sibling
  sheets (`AccountSheet`/`GearStoreScreen`).
- Add a linter rule or documentation note to enforce token usage in monetization screens so
  the violation does not migrate into the next new file.

## Files

- `App/Views/Monetization/BottomDrawer.swift` — system-font usages at lines
  90, 95, 99, 183, 185, 199, 221, 229, 260, 263, 278, 281
- ~~`AccountSheet.swift` (line 46), `GearStoreScreen.swift`, `SaveCardSheet.swift`,
  `SettingsView.swift`~~ — **done** (0 system fonts as of 2026-06-20)
