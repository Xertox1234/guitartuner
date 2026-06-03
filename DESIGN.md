# Tuner (working title) — Design Document

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
2. **Strobe display** as the primary readout — Metal-rendered, buttery at 120 fps.
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
Affiliate "Gear" surface · polyphonic / all-strings-at-once tuning · metronome ·
sweetened / just-intonation temperaments · tuning history · accounts / cloud / sync.
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

---

## 4. Pillar II — The experience layer (visual & interaction)

> Visual experience is a co-equal pillar with accuracy. **Visual direction is locked:**
> bold and stage-ready, dark-first (with a light mode), and a *modern reinterpretation* of
> the strobe as the signature visual.

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
collect is an email address, and **only** if you explicitly opt in (see *Growth* below) —
everything else stays on your device. Mic-permission copy says plainly that audio never
leaves the device.

**Privacy label:** if the opt-in list is collected via a hosted web page (recommended
below), the app itself can keep a clean **"Data Not Collected"** label; if we ever capture
email *in-app*, we honestly declare *Contact Info → Email, used for marketing*. We don't
game the label.

**Monetization:**
- **v1:** **paid up-front — a flat $9.95, one time.** No tiers, no upsell, no purchase
  state to manage. The simplest and most private model there is.
- **v2:** affiliate **physical** gear (guitars/accessories). This is App-Store-clean and
  does **not** require IAP (IAP is only for *digital* content). It also need not dent
  privacy: zero tracking SDKs in-app, affiliate links open in the system browser (the
  retailer logs the click, not us), relationship disclosed per Apple + FTC rules.

**Growth — opt-in email list (legal & ethical by design):**
- **Strictly opt-in, never intrusive.** No pre-checked boxes, never gated in front of the
  tuner, no launch pop-ups. A tasteful entry point in Settings/About with a clear value
  exchange (gear deals + app news).
- **Recommended mechanism — link-out:** signup happens on a hosted page (our site / an ESP
  landing page) opened in the browser. The *app* collects nothing and stays
  networking-free; consent and storage live on the web property under its own clear policy.
  Most on-brand for a privacy-first product. *Alternative:* a minimal in-app form — more
  seamless, but then the app collects email and must declare it.
- **Double opt-in** (email confirmation) — strongest consent record, cleaner list.
- **Compliance baseline:** GDPR (explicit, informed, freely-given consent; easy withdrawal;
  access / erasure; lawful basis = consent), CAN-SPAM (real sender identity, valid physical
  mailing address, prompt one-click unsubscribe), CASL (express consent). A plain-English
  privacy policy linked right at the point of signup.
- **Use & promise:** only offers for products/services related to the app (gear,
  accessories, lessons, our own future apps). **Never sold or rented** to third parties.

---

## 7. Open decisions (next up)

- **Visual direction — LOCKED:** bold & stage-ready, dark-first (+ light mode), strobe as a
  modern reinterpretation. Still to refine: the exact signature-strobe motion design and the
  accent color / palette.
- **App name** — currently unnamed.
- **Exact deployment OS floor.**
- **Final tuning-preset list** for v1.
- **Email list:** collection mechanism (link-out vs. in-app form), ESP choice (e.g.
  Buttondown / ConvertKit / Mailchimp), single vs. double opt-in (recommend double), and
  whether it ships in v1 (a link-out is low-effort) or v2.

---

## 8. Roadmap sketch

- **v1 (MVP):** the eight features in §2 — accurate engine, Metal strobe, chromatic +
  string-lock, presets, A4 calibration, tone generator, paid up-front, fully private.
- **v2+:** affiliate Gear surface · sweetened/just-intonation temperaments · metronome ·
  tuning history — added only once the core is impeccable.
