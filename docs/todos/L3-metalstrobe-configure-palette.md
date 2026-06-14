---
severity: low
audit: 2026-06-12-full
finding: L3
status: closed
closed: 2026-06-14
---

# L3 — `MetalStrobe.configure(_:)` Ignores Palette for `MTKView.clearColor`

**Fix applied (2026-06-14):**
- `MetalStrobe.swift` line 172: `StrobePalette.resolve(scheme).bg` → `StrobePalette.resolve(scheme, palette: palette).bg`
- `self.palette` is already stored on `StrobeRenderer`; no call-site changes needed.
- No observable change for v1 (shader overwrites clearColor), but future palette bg variants will work correctly.
