---
severity: low
audit: 2026-06-12-full
finding: L2
---

# L2 — `StrobeLab` Palette Picker Missing `pickerStyle`

The palette `Picker` in `StrobeLab` has no `.pickerStyle` modifier (falls back to platform
default), while the adjacent strobe-style picker uses `.pickerStyle(.segmented)`.

**File:** `LumaDesignSystem/Strobe/StrobeLab.swift` (lines 109–114)

**Fix:** Add `.pickerStyle(.menu)` to the palette picker.
