---
severity: medium
audit: 2026-06-12-full
finding: M9
---

# M9 — `applyHann` Inner Loops Not Using `vDSP_vmul`

Two scalar window-application loops multiply frame × Hann coefficients element-by-element
in a Swift `for` loop. `Accelerate` is already imported. `vDSP_vmul` is a direct replacement.

**Files:**
- `TunerEngine/Pipeline/PitchPipeline.swift` (lines 224–229)
- `TunerEngine/DSP/SpectralAnalyzer.swift` (lines 73–75)

**Fix:** Replace each loop with:
```swift
vDSP_vmul(frame, 1, w, 1, &frame, 1, vDSP_Length(n))
```
Add `#if canImport(Accelerate)` guards matching `Autocorrelation.swift` for headless-CI portability.

**Tests:** `swift test --package-path Packages/TunerEngine` + benchmark (neutral on accuracy).
