# AuroraStrobe.wrappedDelta called from Radial and Metal — wrong home

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** strobe

## Problem

`AuroraStrobe.wrappedDelta(_:_:)` is a static math utility called by `RadialStrobe` and `MetalStrobe`. It should live alongside other strobe math utilities, not in a specific renderer.

## Fix

- Move `AuroraStrobe.wrappedDelta(_:_:)` to `StrobeMath` alongside `proximity`, `scrollSpeed`, `spread`, and `ringSpeed`
- Update all call sites in `AuroraStrobe`, `RadialStrobe`, and `MetalStrobe`
- Verify no change to behavior

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/AuroraStrobe.swift`
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/RadialStrobe.swift` (line 88)
- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobeMath.swift`
