# Visual & Interaction Design — the Experience pillar

> Experience is co-equal with accuracy. Direction is locked: **bold & stage-ready,
> dark-first (+ light mode), with a *modern reinterpretation* of the strobe** as the
> signature visual. This document goes deep on how that looks and feels.
>
> **Update (2026-06-03):** the design is realised as the **LUMA** system — exact tokens,
> components, and *both* strobe concepts are specified in
> [`design_reference/DESIGN_SYSTEM.md`](design_reference/DESIGN_SYSTEM.md).

---

## 1. Experience principles

1. **The strobe is the hero.** It fills the screen and does the precision work. Everything
   else is quiet around it.
2. **Light, not chrome.** Boldness comes from *luminance and motion* on a dark field —
   glowing accents, blooms, flow — not from heavy UI, borders, or ornament.
3. **Earned stillness.** Motion means "not yet"; stillness means "you got it." The reward
   for tuning is the screen going calm and blooming. That contrast is the whole feeling.
4. **Glanceable from six feet.** You're holding an instrument, phone propped on an amp. The
   note + the strobe must read instantly across a dark stage.
5. **Always alive.** Even silent, the app breathes. There is no dead, empty state.

---

## 2. The signature strobe

**The principle we keep from real strobes:** a pattern whose apparent motion is driven by
the *difference* between your pitch and the target. Off-pitch → it moves; the further off,
the faster; the sign of the error sets the direction. Dead-on → it stands still. This is
perceptually exact — your eye resolves "stopped vs. crawling" far better than it reads a
needle position — which is why strobes are the pro standard.

**What we change:** instead of a literal Peterson band of black rectangles, the motion lives
in a **luminous field** — beautiful enough that you *want* to watch it, while the underlying
math is the same stroboscopic mapping.

**Motion mapping (precise):**
- `cents → drift velocity`. Velocity is proportional to the cents error.
- `sign(cents) → direction`. Sharp drifts one way, flat the other (sharp = clockwise / →,
  flat = counter-clockwise / ←, by convention).
- Near zero the velocity eases toward stillness; inside the **in-tune window (±3 ¢,
  `LOCK_CENTS`)** it locks: motion freezes, the field blooms to the in-tune accent, a haptic taps.
- Driven by the **live phase** from the DSP (not a canned animation), so it's as accurate as
  the engine and naturally sub-cent.

**Three concept directions explored — DECIDED:** ship **both A and B, user-selectable**
(Aurora default, Radial in Settings); **C is dropped from v1.**
- **A — Aurora ribbons (default).** Vertical ribbons of light that slide laterally with the
  error and converge into a single still, glowing column when in tune. Calm but vivid; very
  legible.
- **B — Radial phase ring (Settings).** A glowing ring whose internal phase marks rotate;
  rotation speed = error, frozen = in tune, with a central note. Iconic, scales gorgeously to
  big iPad/Mac screens, makes a strong app-icon language.
- **C — Particle flow (dropped).** A river of luminous particles streaming sideways that
  settles into a stable lattice when locked. The most "alive," the most GPU-ambitious — held
  for a possible future, not v1.

---

## 3. Screen architecture

A single focused screen. Layered, back to front:

1. **Strobe field** — full-bleed background, the hero.
2. **Note readout** — large note name + octave (e.g. `E` with a small `2`), centered.
   Confident display type; the one thing you read from across the room.
3. **Cents readout** — precise signed number (e.g. `−4¢`) in **tabular numerals** so digits
   never jitter; secondary emphasis. Frequency (Hz) available but de-emphasized.
4. **Target chip** — "AUTO" in chromatic mode, or the locked string (e.g. "string-lock: A")
   in manual mode. Tapping enters string selection.
5. **Edge chrome (low emphasis):** input source (DI ▮ / mic), A4 reference, settings,
   tone-generator toggle. Tucked to corners/edges, dimmed until touched.

**Modes**
- **Auto (chromatic):** strobe + nearest note, hands-free.
- **String-lock:** a slim row of the current tuning's strings; tap one to target it. The
  strobe then judges only that pitch — the robust path for low B/E.
- **Tone generator:** long-press / tap a string to *sound* the reference; the strobe view
  stays, so you can match by ear and eye together.

---

## 4. Color & light system

- **Canvas:** near-black with a faint cool tint (e.g. `#0A0B10`), not pure black — blooms
  and glows need somewhere to sit. Light mode inverts to a bright, cool paper with the
  strobe still luminous against it.
- **Error coding (never color alone — paired with motion + direction + numerals):**
  - **Flat** → cool end (electric blue / cyan-violet).
  - **Sharp** → warm end (amber / hot coral).
  - **In tune** → the **signature accent** (a vivid green-cyan), reserved *only* for locked.
    Seeing that color = success, nothing else uses it.
- **Luminosity:** additive blending and bloom (cheap in Metal) make the accents *emit*
  rather than fill. This is the core of "bold & stage-ready."
- **Restraint:** one canvas, two error hues, one sacred in-tune accent. That's the palette.

---

## 5. Typography

- **Note name:** large, confident, slightly characterful display weight — the brand voice.
- **Numerals everywhere (cents, Hz, A4):** **tabular / monospaced figures** so nothing
  shifts as values change. This is non-negotiable for a precision instrument.
- **UI labels:** system font (SF) for full Dynamic Type + localization. Hierarchy:
  Note (huge) › cents (medium) › metadata (small, dim).

---

## 6. Motion, haptics & "juice"

- **120 fps / ProMotion**, display-link-driven, Metal-rendered. Smoothness is the product;
  any stutter breaks the strobe illusion.
- **The lock moment:** field freezes → quick bloom + subtle scale "settle" → a crisp
  **Core Haptics** tap. As you *approach* in-tune, an optional faint haptic texture builds.
- **Note transitions:** the note label cross-fades; values tween — never hard-snap.
- **No-input / attract state:** the field rests in slow, gorgeous ambient motion (a breathing
  aurora / idling ring). The app always looks alive; this idle state is also the brand shot.

---

## 7. Interaction states

| State | Strobe | Note | Feel |
|---|---|---|---|
| **Idle / no input** | slow ambient breathing | dimmed `–` | calm, alive |
| **Acquiring** (attack/transient) | quick ramp-in, slightly unstable | note fades in | "listening" |
| **Tracking** (off-pitch) | flowing, speed = error, hue = sharp/flat | bright | "keep going" |
| **Locked** (in tune) | frozen + bloom, accent color | bright + glow | reward + haptic |

---

## 8. Per-platform

- **iPhone:** portrait hero; controls within thumb reach at the bottom; the propped-up
  "stage" view.
- **iPad:** more immersive strobe; landscape can pair it with a full tuning map / fretboard;
  great as a desk/stage prop.
- **Mac:** a real resizable window **and** an optional **menu-bar micro-strobe** (a tiny live
  ring) for quick checks while recording. Same DSP, same look.
- **Stage Mode (all platforms):** one tap → maximum-contrast full-screen strobe + note, for
  glancing from a distance under lights.

---

## 9. Accessibility as craft

- **Reduce Motion:** a beautiful non-strobe fallback — a precise arc/needle + big numerals —
  not a downgrade, a different first-class view.
- **Never color-alone:** error is also encoded by motion, direction, and the signed number.
- **Color-vision-safe** error hues (validated for protan/deutan); the in-tune accent is
  distinguishable by brightness + the freeze, not hue alone.
- **VoiceOver** speaks note + cents + lock state; **Dynamic Type** on all text.

---

## 10. Brand surface

- **App icon:** a luminous mark drawn from the strobe language (a glowing tuned ring / locked
  waveform on the dark canvas) — recognizable at a glance, consistent with the in-app accent.
- **Cold open:** no splash screen; launch straight into the breathing strobe. The attract
  state *is* the intro.
- **One accent = the brand color**, used sparingly and meaningfully (the in-tune moment).

---

## 11. Visual decisions — resolved

All settled by the **[LUMA design system](design_reference/DESIGN_SYSTEM.md)**:
- **Signature strobe** — **ship both** Aurora (default) and Radial (Settings), selectable;
  reduced-motion gauge as the accessible alternative. Particle flow dropped from v1.
- **Accent palette** — FLAT `#4D8BFF` · SHARP `#FFA53C` · sacred in-tune `#28F0C0`, on a
  `#0A0B10` canvas (full dark + light tokens in the design system).
- **Display typeface** — **Chakra Petch** for the note/display; **JetBrains Mono** for all
  numerals; system font for UI.
- **New (carried from the alternate exploration):** an optional **oscilloscope** scope view,
  restyled into LUMA tokens.
