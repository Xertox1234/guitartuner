# System fonts used in monetization screens instead of LumaFont tokens

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

Multiple monetization screens use `.caption`, `.subheadline`, `.headline`, `.footnote`, `.title2` instead of `LumaFont.display` / `LumaFont.mono`. Design token compliance is required across all screens, not only the tuner UI.

## Fix

- Audit all font usage in monetization screens
- Replace system font references with equivalent `LumaFont` tokens
- Add a linter rule or documentation note to enforce token usage in monetization screens

## Files

- `App/Views/Monetization/AccountSheet.swift` (line 46)
- `App/Views/Monetization/GearStoreScreen.swift`
- `App/Views/Monetization/SaveCardSheet.swift`
- `App/Views/Monetization/SettingsView.swift`
