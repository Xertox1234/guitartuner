---
priority: P2
status: resolved
domain: swiftui
source: 2026-06-15-full audit (M6)
resolved: 2026-06-20
---

> **Resolved 2026-06-20** (branch `fix/bottomdrawer-lumafont-tokens`). Converted all
> 13 raw semantic system-font usages in `BottomDrawer.swift` to `LumaFont` tokens via
> `.lumaUIFont(LumaFont.Size.…)` — sizes map 1:1 to the iOS default text-style points
> (`.caption`→cap/12, `.caption2`→micro/11, `.subheadline`→body/15, `.title3`→xl/20,
> `.largeTitle`→xl3/32), so no visual change at default Dynamic Type. Includes line 197's
> `.largeTitle` icon (not in the original 12-line list — same construct as the line-183
> plus icon; converting only one would re-trigger the "violation moved to a new line"
> cycle). The explicit `.font(.system(size: 9, design: .monospaced))` note chip is left
> intentionally (explicit point size, not a semantic style — passes the audit criterion).
> Second Fix bullet also done: added a typography enforcement rule to
> `docs/rules/swiftui.md` (auto-injects on `App/` edits) so the violation stops migrating
> into new screens. Verified by a green iOS simulator build.

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
