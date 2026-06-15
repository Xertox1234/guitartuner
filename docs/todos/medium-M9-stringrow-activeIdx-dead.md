# StringRow.activeIdx binding write is a dead no-op when .constant(...) is passed

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

`activeIdx = string.idx` inside the button action silently discards when `LiveTunerScreen` passes `.constant(model.activeIdx)`. The effective selection path is exclusively through `onPick`. The API contract is ambiguous; the redundant write should be removed.

## Fix

- Remove the `activeIdx = string.idx` line from the button action
- Document that `onPick` is the authoritative mutator for string selection
- Review `StringRow` call sites to ensure consistency

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StringRow.swift` (line 28)
