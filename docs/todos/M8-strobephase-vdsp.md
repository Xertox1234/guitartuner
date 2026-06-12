---
severity: medium
audit: 2026-06-12-full
finding: M8
---

# M8 — `StrobePhase.bin` Uses Per-Sample cos/sin — No vDSP

`StrobePhase.bin` (called per-hop; twice on bass fallback) loops per sample calling
`cos(a)` and `sin(a)`. The DSP rules require vDSP for inner-loop math. `SpectralAnalyzer.dft`
already implements the same computation with a complex-oscillator recurrence that eliminates
O(N) transcendental calls.

**File:** `TunerEngine/DSP/StrobePhase.swift` (lines 27–35)

**Fix:** Replace the cos/sin loop with the recurrence pattern from `SpectralAnalyzer.dft`.
Numerically equivalent; eliminates the per-sample trig calls.

**Tests:** `swift test --package-path Packages/TunerEngine` + benchmark (should be neutral
on accuracy, measurably faster on bass path).
