---
severity: medium
audit: 2026-06-12-full
finding: M7
---

# M7 — Band-Transition Hysteresis Hardcoded in `nextConfig`

Values 235, 265, 110, 130 Hz in `PitchPipeline.nextConfig` are derived from but not
co-located with the 250/120 Hz band boundaries in `AnalysisConfig`. A future boundary
change would silently break band selection.

**File:** `TunerEngine/Pipeline/PitchPipeline.swift` (lines 233–242)

**Fix:** Move hysteresis margins into `AnalysisConfig` (e.g., `bandHysteresis: Double = 15`)
and derive the four thresholds arithmetically from `bandBoundary ± bandHysteresis`.

**Tests:** `swift test --package-path Packages/TunerEngine` + benchmark after any
`AnalysisConfig` boundary change.
