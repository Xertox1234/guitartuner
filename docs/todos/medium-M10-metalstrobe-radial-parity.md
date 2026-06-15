# MetalStrobe provides no Metal path for RadialStrobe — Aurora/Radial parity gap

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** strobe

## Problem

`useMetalRenderer: true` is silently ignored for `style == .radial`; Radial always uses the Canvas renderer. At 120fps the Canvas RadialStrobe creates ~36 Gradient objects per frame, while AuroraStrobe uses Metal. The two styles have asymmetric GPU utilization that can produce stutter when switching.

## Fix

- Implement a Metal-based RadialStrobe renderer as an alternative to Canvas
- Remove the silent ignore of `useMetalRenderer` for Radial
- Add a warning or assertion to alert developers when Metal is requested but unavailable for a style

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobeField.swift` (line 51)
