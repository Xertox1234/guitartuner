# Plan 03 — Aurora strobe prototype: findings & Canvas-vs-Metal recommendation

Outcome of the first strobe prototype (the deliverable of `03-strobe-prototype.md`).

## What shipped

- **`AuroraStrobe`** — SwiftUI `Canvas` + `TimelineView(.animation)`, additive
  (`.blendMode(.plusLighter)` in dark, `.normal` in light). Ported 1:1 from
  `strobe-aurora.jsx`: scroll speed ∝ cents, direction = sign, proximity
  (`max(0, 1−|cents|/18)`) drives ribbon convergence + the blend toward mint,
  the lock mix eases 0→1 inside ±3¢ → **freeze + central column + bloom halo**.
- **`ReducedGauge`** — the position-encoded arc + eased needle (port of
  `strobe-reduced.jsx`), with a glowing 0→needle fill and a lock ring.
- **`StrobeField`** — swaps Aurora ↔ gauge on `@Environment(\.accessibilityReduceMotion)`.
- **`TunerSimulator`** — port of `useTunerSim` (pluck → converge + wobble),
  driving everything with no audio engine, behind the `StrobeInput` contract.
- **`StrobeLab`** — interactive harness: cents slider, pluck, string row,
  instrument picker, Reduce-Motion toggle, theme toggle, fps readout. Added as a
  tab in the app; the static Tuner screen's hero field now renders Aurora too.
- **Math unit-tested** (`StrobeMathTests`) and exercised by CI on macOS.

## The data contract (engine seam — Plan 01)

```swift
struct StrobeInput { var cents: Double; var phase: Double; var locked: Bool }
```

The prototype integrates lateral **scroll from `cents`** (it only needs the
error to be convincing). `phase` is carried but unused for now — when the engine
lands, its live phase advance drives scroll directly for true sub-cent strobe
precision (the accuracy work and the visual are the same signal, per DESIGN §3).
**To coordinate with Plan 01:** define `phase` as a normalized 0…1 cycle position
of the tracked fundamental; the strobe will scroll by Δphase per frame instead of
the cents-derived approximation.

## fps / performance

The harness shows a smoothed fps from the display clock. **It reports the
refresh cadence, not the true rendering cost** — an authoritative 120 fps /
ProMotion measurement and frame-time profiling require **Instruments on a real
device** (CI builds but can't measure fps; this session had no device). So the
recommendation below is reasoned from the workload, pending on-device numbers.

Per-frame work is light: ~13 vertical gradient bands + one central column + one
radial halo + a hairline, all GPU-backed `Canvas` shadings, no per-pixel CPU
loops. That is comfortably within budget for 60 fps and very likely 120 fps on a
modern iPhone at phone-sized fields.

## Recommendation — **Canvas now, Metal before GA**

- **Ship `Canvas` + `TimelineView` for the prototype and early builds.** It
  reproduces the Aurora faithfully, is tiny, fully previewable, cross-platform,
  and reuses the LUMA tokens directly. Good enough to validate the feel and to
  put in front of people.
- **Commit to the Metal `StrobeRenderer` (DESIGN §5) before GA** if any of these
  hold on-device:
  - the full-bleed hero can't hold **120 fps on ProMotion**, especially on large
    **iPad/Mac** surfaces (Canvas shading cost scales with area);
  - we move to **phase-driven** rendering where sub-frame precision + true
    additive HDR bloom matter;
  - profiling shows `Canvas` re-tessellation per frame costs more than a shader.
  Metal is a drop-in behind the same `StrobeInput`; `AuroraStrobe` becomes the
  fallback / Reduce-Data path.

## Next

- Get on-device fps (iPhone + iPad ProMotion, Mac) and record numbers here.
- Plan 01 `phase` normalization, then switch scroll from cents-derived to phase.
- Radial strobe variant (Settings) when the hero approach is locked.
