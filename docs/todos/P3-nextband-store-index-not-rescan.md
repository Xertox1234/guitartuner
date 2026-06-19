---
priority: P3
status: needs-spec
domain: pipeline, dsp
source: 2026-06-18 PR48 review (nextBand identity-match cleanup)
depends_on: custom/tunable band plans (same trigger as the archived identity-match todo)
---

# `PitchPipeline` could store the current band *index* instead of re-scanning each hop

## Problem

Every analysis hop, `PitchPipeline.analyze()` calls
`Self.nextBand(for:current:in:)`, which does an O(bands) `firstIndex(of: currentBand)`
to relocate the active band before applying hysteresis. With 3–5 bands once per hop the
cost is negligible, so this is purely a structural nit — the per-hop `firstIndex` re-derives
state (the active band's position) that the pipeline could just hold.

Surfaced while reviewing PR48, which replaced the label-string match with value-identity
(`firstIndex(of:)`). Identity match is the right depth for *that* fix; storing the index
would be the deeper form but is out of scope there.

## Fix

Hold `currentBandIndex: Int?` (nil = `acquire` / not-in-`bands`) alongside or instead of
`currentBand`, and have the band-transition step return/advance an index rather than
re-finding it. This is blocked today because:

- `acquire` is **not** a member of `policy.bands`, so there is no natural index for the
  cold-start / unvoiced-reset state — needs a sentinel (`nil`/`-1`).
- `DetectionPolicy.band(forFrequency:)` returns a `BandSpec` **value**, not an index — a
  companion `bandIndex(forFrequency:) -> Int` would be needed.

So this is a small `DetectionPolicy` API addition, not a one-liner. Only worth doing if
custom/tunable band plans land (more bands ⇒ the rescan stops being free) — same trigger as
the archived `P3-nextband-identity-not-label-match` todo. Drop it otherwise.

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (`nextBand`, `currentBand`, `analyze`)
- `Packages/TunerEngine/Sources/TunerEngine/DSP/DetectionPolicy.swift` (`band(forFrequency:)` → add index sibling)

## Verification

Accuracy-gated DSP path: benchmark **zero-delta** required (regenerate `accuracy.csv` at
pre-change vs HEAD with a pinned `--date`, diff must be byte-identical) plus
`swift test --package-path Packages/TunerEngine`. The existing `nextBand` legacy-equivalence
tests (`nextBandReproducesLegacyTransitionsOnSweep`, etc.) pin the behavior.
