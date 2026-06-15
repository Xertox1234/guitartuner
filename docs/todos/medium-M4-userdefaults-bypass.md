# UserDefaults bypass in BottomDrawer — stringly-typed key write

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

`UserDefaults.standard.set(card.palette.rawValue, forKey: "strobePalette")` writes directly instead of going through `@AppStorage`. A key typo silently disconnects the update, the raw `String` write bypasses the `LumaPalette` type system, and future key renames create silent mismatches.

## Fix

- Inject a `Binding<LumaPalette>` into `BottomDrawer` from the caller
- Replace the direct `UserDefaults.set()` call with the binding assignment
- Document that palette selection is the single source of truth for the preference

## Files

- `App/Views/Monetization/BottomDrawer.swift` (line 249)
