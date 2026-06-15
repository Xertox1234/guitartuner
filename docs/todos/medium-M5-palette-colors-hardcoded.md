# Palette preview colors hardcoded as Color(hue:) magic values

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

`paletteColor(_:)` is duplicated verbatim in `BottomDrawer.swift` and `SaveCardSheet.swift` using raw `Color(hue:saturation:brightness:)` values. Design token rule forbids these; palette colors should be exposed via `LumaPalette.color` or `LumaColor.*` tokens.

## Fix

- Create a computed property or helper function in `LumaPalette` to return the preview color
- Replace hardcoded hue tuples in both files with token references
- Verify palette color consistency via `LumaDesignSystem` component preview

## Files

- `App/Views/Monetization/BottomDrawer.swift` (line 300)
- `App/Views/Monetization/SaveCardSheet.swift` (line 113)
