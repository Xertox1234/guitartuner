# LUMA — Design Document

A pro-grade, privacy-first guitar & bass tuner for **iPhone, iPad, and Mac**.

> **Status:** v0.1 planning. This is a living document. No application code has been
> written yet — decisions are captured here first, by design.

---

## 1. Vision & positioning

**One-liner:** The most accurate, best-looking tuner you'll ever buy once — for $9.95.

**Tagline:** *Your playing never leaves your device.* (The only thing we ever collect is an
email address — and only if you explicitly ask us to.)

**The wedge.** The tuner-app market is crowded but soft in one specific corner:
a tuner that is simultaneously (a) genuinely *accurate*, (b) *private*, (c) *pay-once,
no subscription*, and (d) *beautiful*. Most apps are free-with-ads, subscription-bloated,
or buried inside a do-everything multitool. "Accurate, private, pay-once, gorgeous" is a
clean story that sells itself to the exact people who care about tuning.

**Who it's for:** gigging and recording guitarists/bassists, luthiers and techs, and
particular hobbyists — people who would happily pay once for a tool that is tighter and
calmer than the free options.

**Priorities, in order (ties broken top-down):**

1. **Accuracy above all.** This is the product's reason to exist.
2. **Experience / visual craft.** A co-equal pillar — the strobe *is* the product's face.
3. **Privacy by architecture.** Not a setting; a structural guarantee.
4. **Calm, bare-bones scope.** Do a few things impeccably; resist feature creep.

---

## 2. MVP feature set (v1)

1. **Real-time pitch detection** from a wired DI / audio-interface input (auto-preferred
   when present), with the built-in mic as fallback.
2. **Strobe display** as the primary readout — Metal-rendered, buttery at 120 fps. Two
   selectable styles (**Aurora** default / **Radial** in Settings) and a first-class
   reduced-motion gauge. An **optional oscilloscope** (live waveform) is available as a
   secondary scope view.
3. **Chromatic auto-detect** — identifies and shows the nearest note + cents offset, live.
4. **Manual string-lock** — tap a string to judge only sharp/flat against that one target
   (the robustness path for low B/E on bass).
5. **Tuning presets** — guitar (Standard, Drop D, ½-step down, Drop C, …) and bass
   4/5-string (Standard, Drop D, …), built on a chromatic core so alternate tunings are
   just sets of target notes.
6. **Reference calibration** — adjustable A4 (≈430–450 Hz, default 440).
7. **Tone generator** — synthesized reference tones per target note, sharing A4 calibration.
8. **In-tune confirmation** — an unmistakable visual lock + (on iOS/iPadOS) a subtle haptic.

### Explicitly out of scope for v1 (planned v2+)
Affiliate "Gear" surface · **opt-in email signup (in-app form)** · polyphonic /
all-strings-at-once tuning · metronome · sweetened / just-intonation temperaments · tuning
history · accounts / cloud / sync.
None of these belong in v1; all are clean later additions.

---

## 3. Pillar I — The accuracy engine (DSP)

**Accuracy target:** *best achievable on-device.* We do **not** guess a cents figure up
front. We build a benchmark harness (synthesized reference tones + recorded DI of tuned
strings + a calibrated signal source), measure real error and variance across the full
guitar/bass range, and publish the spec **from measured data**.

**Input.** Prefer a clean wired DI signal (USB-C / Lightning interface). A direct signal
with no room noise or reflections is what separates "good app" from "strobe-grade," and is
what makes the best-achievable goal actually reachable. Mic is a graceful fallback.
Capture via **AVAudioEngine**, mono, 48 kHz; explicitly select/prefer an external input.

**Pipeline.**

```
capture → high-pass (kill <~25 Hz rumble) → fundamental tracking → sub-cent refinement
        → sustain gating + light smoothing → note + cents (+ phase to drive the strobe)
```

- **Fundamental tracking (octave-safe):** McLeod Pitch Method (NSDF) and/or YIN. These
  track the *fundamental*, which matters because real strings are slightly **inharmonic** —
  partials sit a touch sharp of exact integer multiples. Naive "tallest FFT peak" methods
  get biased by that and quietly lose accuracy on exactly the notes we care about. We tune
  to the fundamental.
- **Sub-cent refinement:** parabolic interpolation around the NSDF peak for sub-sample
  period precision, plus **phase-vocoder** frequency estimation (phase advance between hops
  gives a very fine instantaneous frequency). Convenient bonus: that phase signal is
  *exactly* what drives a true strobe — the accuracy work and the signature visual are the
  same work.
- **Sustain gating:** pluck attacks are noisy transients. Gate on a confidence metric
  (NSDF peak height) so we lock onto the stable sustain, then smooth with a short
  median/EMA to kill jitter without adding perceptible lag.

**The bass latency floor (real, but fine).** Low B (~31 Hz) has a ~32 ms period; we need
~2–3 periods (~65–100 ms of audio) just to *see* it, so the lowest notes settle in
~100–150 ms. You hold a tuning note anyway, so this reads as "rock-solid," not "laggy."
Guitar and higher notes stay snappy via overlapping analysis hops.

**Status — built & measured.** The engine is implemented as the shared, UI-free
[`TunerEngine`](Packages/TunerEngine/) package (Plan 01): MPM/NSDF (with YIN + a hybrid)
fundamental tracking, parabolic + phase-vocoder sub-cent refinement, the strobe phase,
confidence/sustain gating, and median/EMA smoothing — chromatic, with an optional
string-lock target. The strobe `phase` is normalized as a 0…1 cycle position of the
tracked fundamental, so the Aurora strobe scrolls by Δphase for true sub-cent precision
(EXPERIENCE §2).

**Measured accuracy (from data, not guesses).** A headless benchmark
([`docs/benchmarks/accuracy.md`](docs/benchmarks/accuracy.md)) runs on every CI build —
synthesized pure / harmonic / **inharmonic-string** tones across the full guitar+bass
range at known cents, plus SNR sweeps. The current measured spec:

| Metric | Result |
|---|---|
| Mean abs cents error (clean) | **1.42 ¢** |
| Mid/high range (most of the guitar) | **0.2–0.8 ¢** abs |
| Low bass (≤ ~98 Hz) | ~3 ¢ abs (≤ ~26 ¢ at the extreme-detuned lowest notes) |
| **Octave-error rate** | **0.00 %** across 207 cases, incl. 5-string low B (30.87 Hz) |
| Noise robustness | abs ~0.8 ¢, **0 octave errors** down to **10 dB SNR** |
| Time-to-lock | ~43 ms median (cold start); lowest strings settle ~100–150 ms |

So the accuracy pillar reads as designed: **strobe-grade and octave-safe**, sub-cent where
it matters, with the only meaningful error confined to the extreme-detuned lowest notes
(physics: ~2–3 periods per window), and rock-solid under noise.

---

## 4. Pillar II — The experience layer (visual & interaction)

> Visual experience is a co-equal pillar with accuracy. **Visual direction is locked:**
> bold and stage-ready, dark-first (with a light mode), and a *modern reinterpretation* of
> the strobe as the signature visual. The concrete tokens, components, and both strobe
> concepts now live in the **[LUMA design system](docs/design_reference/DESIGN_SYSTEM.md)**.

**Philosophy:** *bold, luminous, instantly legible.* High-contrast and high-energy — vivid
accent light on a deep dark canvas, readable at a glance from across a dark stage or studio
with your hands full. Uncluttered but striking, not clinical: the strobe is a centerpiece
you *want* to watch. Boldness comes from focus and contrast, never clutter.

- **The strobe is the hero — reimagined.** Not a literal Peterson band but a fresh
  signature visual (e.g. a luminous, flowing field whose motion encodes pitch error), with
  true-strobe precision underneath. Rendered in **Metal** (a fragment shader driven by the
  live phase/frequency) for flawless motion at 120 fps on ProMotion — any jank destroys the
  illusion, so it gets a dedicated render path. SwiftUI handles all surrounding chrome.
- **The in-tune moment** is the emotional payoff: the field locks and stills, a vivid accent
  bloom and soft glow, and a subtle **Core Haptics** tap on iOS/iPadOS. It should feel
  *earned and satisfying*.
- **Glanceability:** large, legible note name; **tabular (monospaced) numerals** for cents
  so the readout never jiggles; **dark-first** for stage/low-light (with a polished light
  mode); vivid, high-contrast accents tuned to read under stage lighting.
- **Accessibility is part of craft, not an afterthought:** never rely on color alone
  (encode sharp/flat with position/shape too); honor **Reduce Motion** with a clean
  needle/numeric alternative to the strobe; full VoiceOver and Dynamic Type support.
- **Tone generator UX:** tap a target note to sound it; sustained, pleasant timbre (a touch
  of harmonic richness, not a harsh sine); tracks the A4 calibration.
- **Per-platform, considered:**
  - **iPhone** — one-handed, portrait-first, instantly glanceable.
  - **iPad** — uses the larger canvas; the strobe scales beautifully; room for more context
    in landscape.
  - **Mac** — a real window *and* an optional **menu-bar tuner** for quick access while
    recording. The DSP is identical across all three.

---

## 5. Architecture & stack

**Confirmed: native Swift, no cross-platform runtime.** The iPhone/iPad/Mac trio plus
low-latency precision audio rules out JS/Flutter layers between us and the samples.

- **App targets:** one **SwiftUI multiplatform** app (true multiplatform, *not* Mac
  Catalyst) for iPhone / iPad / Mac.
- **`TunerEngine` (shared Swift package):** capture + DSP, **no UI**. AVAudioEngine for
  I/O and input selection; **Accelerate / vDSP** for the math. Independently testable and
  benchmarkable.
- **`StrobeRenderer`:** the Metal strobe layer, fed by `TunerEngine`'s phase output.
- **No networking in v1** — reinforces the privacy guarantee structurally.
- **Deployment floor:** target the two most recent major OS releases to use current
  SwiftUI, Swift concurrency, and Metal. Exact floor **TBD** (see §7).

---

## 6. Privacy & monetization

**Privacy (a structural feature):** *your playing never leaves your device.* All audio is
processed **on-device** and is never recorded, stored, or transmitted — no accounts, no
registration, no analytics SDKs, and no networking for the tuner itself. This isn't a
promise you have to trust; the architecture makes it true. The **only** data we ever
collect is an email address, and **only** if you explicitly opt in (a **v2** feature — see
*Growth* below); **v1 collects nothing**, and everything else always stays on your device.
Mic-permission copy says plainly that audio never leaves the device.

**Privacy label:** **v1 collects nothing → a clean "Data Not Collected" label.** The opt-in
email form is a **v2** addition; because it captures email *in-app*, v2 honestly declares
*Contact Info → Email, used for marketing*. We don't game the label.

**Monetization:**
- **v1:** **paid up-front — a flat $9.95, one time.** No tiers, no upsell, no purchase
  state to manage. The simplest and most private model there is.
- **v2:** affiliate **physical** gear (guitars/accessories). This is App-Store-clean and
  does **not** require IAP (IAP is only for *digital* content). It also need not dent
  privacy: zero tracking SDKs in-app, affiliate links open in the system browser (the
  retailer logs the click, not us), relationship disclosed per Apple + FTC rules.

**Growth — opt-in email list (v2; legal & ethical by design):**
- **Strictly opt-in, never intrusive.** No pre-checked boxes, never gated in front of the
  tuner, no launch pop-ups. A tasteful entry point in Settings/About with a clear value
  exchange (gear deals + app news).
- **Mechanism — in-app form, shipping in v2 (decided):** a minimal, tasteful email field
  inside the app, posted to our ESP. Because it ships in **v2**, **v1 stays networking-free
  with a clean "Data Not Collected" label.** In v2 the form brings an in-app consent UI, a
  linked privacy policy, the app's single isolated network call (to the ESP), and an honest
  label update (*Contact Info → Email, used for marketing*).
- **Double opt-in** (email confirmation) — strongest consent record, cleaner list.
- **Compliance baseline:** GDPR (explicit, informed, freely-given consent; easy withdrawal;
  access / erasure; lawful basis = consent), CAN-SPAM (real sender identity, valid physical
  mailing address, prompt one-click unsubscribe), CASL (express consent). A plain-English
  privacy policy linked right at the point of signup.
- **Use & promise:** only offers for products/services related to the app (gear,
  accessories, lessons, our own future apps). **Never sold or rented** to third parties.

---

## 7. Open decisions (next up)

- **Visual direction — LOCKED & specified:** the full **LUMA design system** is now in hand
  (Chakra Petch + JetBrains Mono; the dark/light palette; FLAT blue / SHARP amber / sacred
  mint in-tune; glow-not-shadow elevation). Strobe decision: **ship both Aurora and Radial,
  user-selectable** (Aurora default), plus the reduced-motion gauge. See
  [`docs/design_reference/DESIGN_SYSTEM.md`](docs/design_reference/DESIGN_SYSTEM.md).
- **App name — LOCKED: LUMA.**
- **Exact deployment OS floor.**
- **Final tuning-preset list** for v1.
- **Email list (v2, in-app form — decided):** remaining choices are the ESP (e.g.
  Buttondown / ConvertKit / Mailchimp) and single vs. double opt-in (recommend double).

---

## 8. Roadmap sketch

- **v1 (MVP):** the eight features in §2 — accurate engine, Metal strobe, chromatic +
  string-lock, presets, A4 calibration, tone generator, paid up-front, fully private.
- **v2+:** affiliate Gear surface · opt-in email signup (in-app form) ·
  sweetened/just-intonation temperaments · metronome · tuning history — added only once the
  core is impeccable.

**Build plans:** session-ready plans for the first three engineering workstreams — the DSP
engine, the SwiftUI design-system scaffold, and the first strobe prototype — live in
[`docs/plans/`](docs/plans/).
