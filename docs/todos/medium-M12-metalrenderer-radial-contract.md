# useMetalRenderer silently ignored for Radial — misleading API contract

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** strobe

## Problem

`StrobeField` accepts `useMetalRenderer: Bool` but ignores it when `style == .radial` with no warning, assertion, or documentation. Callers passing `true` with `.radial` silently get Canvas. The parameter's contract is ambiguous.

## Fix

- Scope `useMetalRenderer` to Aurora-only or
- Trigger an `assertionFailure` in debug builds when the parameter is contradicted
- Add clear documentation stating which styles support Metal rendering

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobeField.swift` (line 24)
