---
severity: medium
audit: 2026-06-12-full
finding: M7
---

# M7 — Band-Transition Hysteresis Hardcoded in `nextConfig` — RESOLVED (instrument-profiles Slice 1)

**Status: RESOLVED** by the 2026-06-17 instrument-profiles Slice 1 refactor. The hardcoded
235/265/110/130 Hz thresholds in the former `PitchPipeline.nextConfig` no longer exist. Band
transition now flows through `PitchPipeline.nextBand`, which derives its rise/fall thresholds
**arithmetically** as `floorHz ± hysteresisHz` from each `BandSpec` in the active
`DetectionPolicy`. The per-band `floorHz`/`hysteresisHz` fields are sourced directly from the
`AnalysisConfig` boundary + hysteresis constants in the `.fullRange` preset
(`DetectionPolicy.swift` — `highMidHz`/`highMidHysteresis`, `midLowHz`/`midLowHysteresis`,
`lowUltraLowHz`/`lowUltraLowHysteresis`). A future boundary change in `AnalysisConfig` now flows
through automatically, so the original silent-break risk is closed — exactly the fix this finding
prescribed (co-locate the margins, derive thresholds from `boundary ± hysteresis`).

## Original finding (for the audit trail)

Values 235, 265, 110, 130 Hz in `PitchPipeline.nextConfig` were derived from but not
co-located with the 250/120 Hz band boundaries in `AnalysisConfig`. A future boundary
change would silently break band selection.

**Fix (applied):** Move hysteresis margins alongside the band boundaries (now per-band
`BandSpec.hysteresisHz`, sourced from `AnalysisConfig`) and derive the thresholds arithmetically
from `boundary ± hysteresis` (now in `PitchPipeline.nextBand`).

**Tests:** `swift test --package-path Packages/TunerEngine` (100 tests, incl.
`nextBandReproducesLegacyTransitionsOnSweep`) + accuracy benchmark — both green; Slice 1 proved
byte-identical (sha256) benchmark output vs the pre-refactor baseline.
