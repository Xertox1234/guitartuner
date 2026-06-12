---
severity: low
audit: 2026-06-12-full
finding: L3
---

# L3 — `MetalStrobe.configure(_:)` Ignores Palette for `MTKView.clearColor`

`configure` calls `StrobePalette.resolve(scheme)` without `palette`. Currently harmless
(the shader overwrites every pixel; `bg` slot doesn't vary by palette), but will become
a visual bug if any palette variant adds a `bg` color.

**File:** `LumaDesignSystem/Strobe/MetalStrobe.swift` (line 172)

**Fix:** Change `configure(_ view: MTKView, palette: LumaPalette)` and pass `self.palette`
from both call sites (`makeView` and `update(scheme:view:)`).
