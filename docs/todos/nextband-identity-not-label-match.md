# `PitchPipeline.nextBand` should match the current band by identity, not by label string

**Severity:** Low (latent footgun — not reachable by any current policy)
**Source:** 2026-06-17 instrument-profiles Slice 1 — Task 4 code-quality review (deferred).
**Domain:** pipeline, dsp
**Apply when:** a `DetectionPolicy` with two bands sharing the same `label` becomes possible —
i.e. when custom/tunable band plans land (the deferred bass-fix slice, or any future
custom-policy feature). Not needed while only `.fullRange`/`.guitar`/`.bass` exist.

## Problem

`PitchPipeline.nextBand(for:current:in:)` locates the current band via label-string match:

```swift
guard let i = bands.firstIndex(where: { $0.label == current.label }) else { ... }
```

If a future custom policy ever contains two `BandSpec`s with the same `label`, this returns the
**first** band with that label, which may not be the one actually active — corrupting the
hysteresis-based band transition logic. `BandSpec` is `Equatable`, so identity matching is
available and unambiguous.

For the three built-in presets this is a non-issue: each has unique band labels
(high/mid/low/ultralow + acquire), and `current` is always one of the active policy's bands, so
`firstIndex(where: label ==)` and `firstIndex(of:)` return the same index. The Slice 1 zero-delta
proof (sha256-identical benchmark, merge-base ≡ HEAD) holds either way.

## Fix

```swift
guard let i = bands.firstIndex(of: current) else { return policy.band(forFrequency: f0) }
```

Because this touches a CI-gated DSP path, re-run the accuracy benchmark and confirm the
zero-delta proof still holds (regenerate accuracy.csv at the pre-change commit and at HEAD with a
pinned `--date`, diff — must be byte-identical) before committing.

Optional companion rename deferred from the same review: `PitchPipeline.config` →
`currentBand` (the stored property is now a `BandSpec`, not an `AnalysisConfig`).

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (`nextBand`, `config`)
