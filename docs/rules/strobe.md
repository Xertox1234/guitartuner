# Strobe rules

- `PitchReading.phase` is a **0…1 normalized cycle position** of the tracked fundamental against the nearest-note reference oscillator. On pitch it stands still; off pitch it advances at the beat rate (∝ Hz error). The strobe scrolls by Δphase between readings — this is true-strobe precision.
- `phaseScroll: true` is the live-tuner mode (phase-driven). `phaseScroll: false` is position-based (for simulator/preview use). Always use `phaseScroll: true` in the live tuner path.
- `StrobeInput` is the **only** data contract between `LiveTunerModel` and the strobe renderers. Do not bypass it. Do not add fields to `StrobeInput` without considering every renderer that consumes it.
- The Metal renderer targets ProMotion (up to 120 fps). Any synchronous work that blocks the render thread causes visible jank that destroys the strobe illusion. Keep the render path allocation-free.
- Always honor `@Environment(\.accessibilityReduceMotion)`. When reduce motion is enabled, substitute the `ReducedGauge` readout — do not just slow the animation. Canonical (with Reduce Transparency, Dynamic Type, VoiceOver, contrast): `docs/rules/accessibility.md`.
- Aurora and Radial are both first-class; neither is deprecated or secondary. The user selects via `@AppStorage("strobeStyle")`.
- The **in-tune lock moment** — phase standing still, bloom activating, haptic firing — is the emotional core of the product. Do not degrade it. Changes to the strobe state machine require explicit review of the lock transition.
- Renderers must derive `inLock` from `input.locked` **only** — never from `abs(input.cents) < lockCents`. The confidence gate lives in `LiveTunerModel`; replicating it in the renderer causes false-lock bloom during bass attacks where cents error is small but confidence is low.
