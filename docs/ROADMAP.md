# LUMA — Roadmap & Backlog

> A **living checklist** of remaining and easily-forgotten work. Tick items off and
> add new ones as you go. Canonical *intent* still lives in
> [`DESIGN.md`](../DESIGN.md) / [`docs/EXPERIENCE.md`](EXPERIENCE.md) and the
> session plans in [`docs/plans/`](plans/) — **this file is the running task list**,
> not the spec.
>
> Convention: `- [ ]` open · `- [x]` done. Group by area. Link the spec section so
> intent is one click away.

---

## v1 MVP — what's left

The eight MVP features (DESIGN §2): #1,3,4,5,6,7,8 are **done** (see *Shipped* below).
The remaining pillar is **#2, the strobe / experience layer** — co-equal with
accuracy, so worth doing well.

### Strobe & experience (DESIGN §2.2, EXPERIENCE §2/§8/§11)
- [x] **Radial Phase Ring** strobe variant — second hero visual, rendered from the
      existing `StrobeInput` contract (cents/phase/locked). Decision is locked:
      *ship both, user-selectable*. *(Plan 05.)*
- [x] **Strobe Settings toggle** — Aurora (default) / Radial, persisted in
      `@AppStorage`; the reduced-motion gauge still auto-engages on Reduce Motion.
      *(Plan 05.)*
- [x] **Metal `StrobeRenderer`** — the 120 fps GPU hero path, a drop-in behind
      `StrobeInput` (DESIGN §5). `MetalStrobe` (`MTKView` + a runtime-compiled MSL
      shader) reproduces the Aurora field on the GPU. **Opt-in** (Settings → Display
      "Metal renderer", Aurora only; A/B in the Strobe lab against its fps readout);
      the Canvas Aurora stays the default. Pure `StrobeShaderColors` unit-tested.
      *Landed CI-only — the 120 fps device pass is tracked below.*
- [x] **Optional oscilloscope** — live-waveform scope view, restyled into LUMA
      tokens (carried over from the alternate exploration; DESIGN_SYSTEM §Oscilloscope).
      `Oscilloscope` + pure `ScopeMath`; opt-in via Settings, shown under the readouts.
- [x] **Mac menu-bar micro-strobe** — a tiny live ring for quick checks while
      recording (EXPERIENCE §8). Same DSP, same look. `MenuBarExtra` (window style)
      reusing `StrobeField` + the readouts, driven by the *one* `LiveTunerModel`
      (hoisted to `LumaApp`, shared with the main window); the bar glyph shows the
      note while listening (pure `MenuBarStrobe.caption`, unit-tested). *In-bar
      animated ring deferred to the on-device pass.*
- [x] **Stage Mode** — one-tap max-contrast full-screen strobe + note, all platforms.
      `StageView` + a top-chrome toggle; keeps the screen awake on iOS.

### Polish / first-run (DESIGN §10, EXPERIENCE §10)
- [x] Bundle **Chakra Petch + JetBrains Mono** (OFL 1.1) — vendored into the
      package `Fonts/` bundle (Chakra Petch SemiBold; JetBrains Mono Regular +
      Medium) with their `OFL.txt`, registered at launch by `LumaFonts`. Family
      names verified to resolve as `Chakra Petch` / `JetBrains Mono`; SF Pro /
      SF Mono stays the fallback. *(On-device: confirm the faces render — CI can't
      rasterize.)*
- [x] Real **app icon** drawn from the strobe language — a glowing mint tuned ring
      + central lock column on the canvas (the in-tune moment), generated
      reproducibly by `Tools/make_app_icon.py` (pure-stdlib PNG, no deps): iOS 1024
      full-bleed + every macOS size on the squircle, legible to 16pt.
- [x] **Cold open** straight into the breathing strobe (no splash). Release ships
      the *single focused screen* (`RootView` → `LiveTunerScreen`; the strobe lab +
      design gallery are now DEBUG-only); the iOS launch screen is tinted to the
      canvas (`LaunchCanvas` = `lumaBg`, light/dark) so there's no white flash into
      the strobe. Theme (System/Dark/Light) moved to Settings → Appearance.

---

## On-device verification (cannot run in CI)

CI compiles everything and runs the headless DSP, but live audio / haptics need
hardware. Track a real-device pass:

- [ ] Live capture: **DI-preferred + mic fallback** on iOS *and* macOS hardware.
- [ ] **Tone while listening** — `ToneGenerator` switches the iOS `AVAudioSession`
      to `.playAndRecord`; confirm it doesn't glitch capture or re-enable AGC on the
      analysis path. *(Flagged during Plan 04.)*
- [ ] **Core Haptics** lock tap on iPhone / iPad (and that it's a clean no-op
      elsewhere).
- [ ] Permission prompts + entitlements: `NSMicrophoneUsageDescription` (present),
      macOS `com.apple.security.device.audio-input` for a sandboxed/notarized build.
- [ ] **Metal hero (`StrobeRenderer`)** — confirm the GPU path matches Aurora's look
      and holds **120 fps** on a ProMotion panel (Strobe lab fps readout), the
      light/dark blends read right, and Settings → Display "Metal renderer" swaps
      cleanly. *(Landed CI-only; opt-in, Aurora.)*

---

## Open decisions (DESIGN §7)

- [ ] **Deployment OS floor** — still TBD (currently iOS 17 / macOS 14).
- [x] **Final tuning-preset list** — resolved in Plan 04.
- [ ] *(v2)* Email **ESP** choice + single vs. double opt-in (recommend double).

---

## Parked — v2+ (explicitly out of scope for v1)

Affiliate "Gear" surface · opt-in email signup (in-app form) · polyphonic /
all-strings-at-once tuning · metronome · sweetened / just-intonation temperaments ·
tuning history · accounts / cloud / sync. *(DESIGN §2 "out of scope", §8.)* No
networking in v1, ever.

---

## Shipped (v1)

- [x] **Plan 01 — TunerEngine**: MPM/NSDF + YIN/hybrid, sub-cent refine, strobe
      phase, gating/smoothing; headless accuracy benchmark (0% octave errors, ~1.4¢).
- [x] **Plan 02 — LUMA design system**: tokens, components, gallery.
- [x] **Plan 03 — Aurora strobe prototype**: `Canvas` + `TimelineView`, reduced-motion
      gauge, `StrobeLab` simulator.
- [x] **Plan 04 — Tuner UX**: manual string-lock + Auto/String mode, tuning presets
      (guitar + bass 4/5-string), A4 calibration, on-device tone generator, in-tune
      Core Haptics, Settings sheet.
- [x] **Plan 05 — Radial strobe + style toggle**: `RadialStrobe` phase-ring hero
      (port of `strobe-radial.jsx`), a peer of Aurora behind `StrobeField`/`StrobeInput`
      with the same phase-driven true-strobe path; Aurora/Radial selector in Settings
      (`@AppStorage`) + the Strobe lab; Reduce Motion still overrides to the gauge.
      Pure `ringSpeed`/`markEnvelope` math unit-tested.
