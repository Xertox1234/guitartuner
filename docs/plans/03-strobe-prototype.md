# Plan 03 — First strobe prototype (Aurora)

> Execute in its own session. Validates the **Aurora** strobe motion in SwiftUI and locks the
> rendering approach + the data contract before the Metal hero path.

## Goal
An interactive **Aurora ribbons** prototype: motion = pitch error, direction = sign,
converging + freezing + blooming mint at lock — running smoothly in SwiftUI, driven by a
simulator (so it needs no engine), with the reduced-motion gauge fallback. Output a clear
**Canvas-vs-Metal** recommendation.

## Prerequisites & references
- `docs/design_reference/strobe-aurora.jsx` + `strobe-core.jsx` (the math) + `strobe-reduced.jsx`
- `docs/EXPERIENCE.md` §2 (motion mapping), §6 (juice / lock)
- `docs/design_reference/DESIGN_SYSTEM.md` (colours; lock = ±3 ¢)
- `prototypes/strobe-concepts.html` (the web reference to match the feel)
- Ideally **after Plan 02** (uses the colour tokens); can stub colours if run first.

## In scope
The Aurora view · the simulator · the interactive harness · the reduced-motion gauge · a perf
measurement + rendering decision.

## Out of scope
The Radial strobe (later; Settings) · the real engine · final Metal shipping code.

## Plan

### 1. Port the math (`strobe-core.jsx` → Swift)
- Constants: `LOCK_CENTS = 3.0`, `TRACK_CENTS = 50`, ribbon `count ≈ 13`.
- `cents → scroll speed` (∝ error, frozen at lock); `sign → direction`;
  `prox = max(0, 1 − |cents|/18)` drives convergence (ribbon spread compresses) and the colour
  blend toward mint; `lock` eases 0→1 inside ±3 ¢ → **freeze + bloom**.
- Brightness: gaussian envelope (bright centre column), additive blend, a growing central
  column, a radial bloom halo at lock. Mirror `strobe-aurora.jsx` `draw()`.

### 2. Rendering — try in order
1. **SwiftUI `Canvas` + `TimelineView(.animation)`** — additive via `.blendMode(.plusLighter)`
   / `GraphicsContext`. One clock; read cents from a value (not per-frame view rebuilds).
   Validate the look + **fps**.
2. If Canvas can't hold **120 fps / ProMotion**, spike the **Metal** path (`StrobeRenderer`:
   `CAMetalLayer` / `MTKView` in SwiftUI; fragment shader; uniforms `cents, phase, lock,
   palette`). `DESIGN.md` commits the hero strobe to Metal — this prototype **decides
   Canvas-good-enough vs Metal** from measured fps.

### 3. Simulator (port `useTunerSim`)
- "Pluck" → jump to a random out-of-tune offset → converge to 0 with micro-wobble, easing as
  it locks; plus a manual **cents slider**. Drives the prototype with **no engine.**
- Define the contract the engine will later satisfy:
  ```swift
  struct StrobeInput { var cents: Double; var phase: Double; var locked: Bool }
  ```
  (coordinate `phase` normalization with Plan 01.)

### 4. Reduced motion
Wire `@Environment(\.accessibilityReduceMotion)` → swap Aurora for the **ReducedGauge** (port
`strobe-reduced.jsx`: arc + eased needle, position-encoded). First-class, not a downgrade.

### 5. Harness screen
Aurora full-bleed + the note/cents readouts (reuse Plan 02 components if present) + slider +
pluck button + a dark/light toggle + an fps counter. Mirror `prototypes/strobe-concepts.html`.

## Definition of done
Aurora moves correctly (speed / direction / convergence) and **freezes + blooms** at lock in
dark + light; the reduced-motion gauge works; an fps note + a written **Canvas-vs-Metal**
recommendation is recorded.

## Open questions (resolve in-session)
Canvas additive-blend fidelity & fps on device · how `phase` (engine) blends with the
simulator's cents-only model · whether to ship Canvas for v1 or commit to Metal now.

## Kickoff prompt
> Read `docs/design_reference/DESIGN_SYSTEM.md`, the `strobe-*.jsx` in
> `docs/design_reference/`, `docs/EXPERIENCE.md` (§2, §6), and
> `docs/plans/03-strobe-prototype.md`. Build the **Aurora** strobe prototype in SwiftUI
> (`Canvas` + `TimelineView`) driven by a port of `useTunerSim` with a cents slider + pluck
> button, plus the reduced-motion gauge, in dark + light. Measure fps and record the
> Canvas-vs-Metal decision. Match `strobe-aurora.jsx` behaviour.
