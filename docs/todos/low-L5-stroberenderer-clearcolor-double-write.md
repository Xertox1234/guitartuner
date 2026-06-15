# StrobeRenderer.configure() double-writes clearColor per scheme change

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** strobe

## Problem

`update(scheme:view:)` calls `configure(view)` on every scheme change, re-setting `view.clearColor`. The fragment shader writes `colBg` over the full framebuffer every frame, making the `clearColor` set in `configure()` cosmetically redundant.

## Fix

- Remove the redundant `clearColor` assignment from `configure()`
- Verify that visual output remains identical in light/dark modes
- Add a comment documenting that the shader handles background rendering

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/MetalStrobe.swift` (line 176)
