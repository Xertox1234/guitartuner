# Plan 06 — Project Strobe‑Grade: the accuracy ceiling

> Execute in its own session(s). Pushes LUMA's `TunerEngine` from **excellent**
> (1.42 ¢ mean, 0.2–0.8 ¢ across the core of the guitar) to **the most accurate
> tuner ever shipped** — strobe‑grade in the core range, an order of magnitude
> better on the low strings, and *measured*, not claimed. Accuracy is the
> product's reason to exist (`DESIGN.md` §1, §3); this is the plan that takes it
> to the physical ceiling.
>
> **Posture (unchanged from Plan 01): best achievable on‑device; measure, don't
> guess.** Every number below is either reproduced from the current engine, hand‑
> derived, or cited. Every phase is gated by the benchmark.

---

## 0. TL;DR — the thesis in six lines

1. The current engine is **bass‑limited**: virtually the entire error budget lives
   below 82 Hz, and its signature is **string inharmonicity**, not noise.
2. The fix is a **harmonic, inharmonicity‑aware, statistically‑efficient
   estimator** (fast harmonic NLS + joint `B`) that uses *all the partials* instead
   of tracking the lone fundamental — the high partials are where the frequency
   information lives, especially on low strings.
3. A **long‑window phase‑slope ("virtual strobe") lock** drives the steady‑state
   reading to the noise floor (sub‑0.05 ¢) on a held note — the same phase that
   already drives the Aurora/Radial strobe.
4. Replace raw **parabolic interpolation** (≈0.5 ¢ of irreducible bias, reproduced
   below) with a **bias‑corrected** estimator.
5. Be **honest about the ceiling**: relative/strobe accuracy is ~0.02 ¢ and
   clock‑immune; *absolute* A=440 is floored by the device sample clock
   (±0.04–0.17 ¢) unless we calibrate it. Ship the calibration; state the limit.
6. **Prove all of it** by upgrading the benchmark to measure σ, worst‑case, and
   CRLB‑efficiency at the sub‑0.1 ¢ level, with progressively tighter CI gates.

Target spec (to be confirmed *from data*, per project ethos):

| Metric | Today (reproduced) | Target |
|---|---|---|
| Mean abs error, core range (≥120 Hz) | 0.2–0.8 ¢ | **≤ 0.1 ¢** |
| Steady‑state jitter σ, held note | 3.31 ¢ pooled | **≤ 0.05 ¢** (lock) |
| Low bass (≤ 82 Hz) abs error | 2.96 ¢ (worst 25.7 ¢) | **≤ 1 ¢** (worst ≤ 3 ¢) |
| Octave‑error rate | 0.00 % | **0.00 %** (hold the line) |
| Absolute A=440, *uncalibrated* | unstated | honestly **≤ 0.2 ¢** (clock‑bound) |
| Absolute A=440, *calibrated* | n/a | **≤ 0.02 ¢** |

---

## 1. Where we are vs. the bar

**Reproduced baseline** (this engine, `swift run -c release Benchmark`, commit at
time of writing — identical to the committed `docs/benchmarks/accuracy.md`):

| Range | n | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|
| bass (<82 Hz) | 2472 | **2.96** | 5.22 | **25.71** |
| mid (82–330 Hz) | 2236 | 0.76 | 1.33 | 9.52 |
| high (>330 Hz) | 1944 | 0.22 | 0.36 | 2.58 |

The bar set by the best tuners in the world (all cited, §13/§14):

| Tuner | Spec | Kind |
|---|---|---|
| Sonic Research Turbo Tuner, TC PolyTune (strobe) | **±0.02 ¢** | true strobe, TCXO reference |
| Peterson StroboPlus / StroboStomp / iStroboSoft | **±0.1 ¢** | virtual strobe |
| TonalEnergy, insTuner, n‑Track | 0.1 ¢ *display* | software, calibration‑qualified |
| Cleartune | ±1 ¢ | software (honest) |

"Most accurate ever" is therefore an operational target: **beat the 0.1 ¢ virtual‑
strobe class in the core range and approach the 0.02 ¢ true‑strobe class in the
held‑note lock**, while being the first to *publish a measured* low‑string number
that the strobe pedals never quote.

---

## 2. Diagnosis — the error budget and its root causes

Four independent, reproduced probes (scripts in §16; all run clean on this repo's
Swift toolchain) localise the entire opportunity.

### 2.1 The bass error is inharmonicity, not noise
The benchmark's worst case is **25.71 ¢** on the extreme‑detuned lowest notes. That
is not random — it is the *signature of string stiffness*. For the benchmark's own
stiff‑string model (`B = 3e‑4`), partial sharpness follows the standard rule
`Δcents(n) ≈ 865.62·B·n²`:

```
n= 1:   0.26¢     n= 5:   6.47¢     n= 8:  16.46¢     n=10:  25.59¢
```

The 10th‑partial sharpness (**25.59 ¢**) ≈ the benchmark's worst case (**25.71 ¢**).
Any estimator that lets stretched partials pull on the fundamental estimate inherits
this bias. A crude single‑fundamental autocorrelation + parabolic estimate on this
exact signal reads **+10.6 ¢ sharp** — and *no amount of averaging removes it*,
because it is bias, not variance.

### 2.2 Parabolic interpolation has its own irreducible bias
Reproduced on a pure tone, N=4096 Hann, swept across fractional‑bin offsets:

| Peak interpolator | worst‑case error |
|---|---|
| **parabolic (linear magnitude)** | **0.457 ¢** ( = 5.3 % of a bin — matches Abe & Smith exactly) |
| parabolic (log magnitude) | 0.139 ¢ |
| Candan‑2013 / A&M (2 iters) | near‑CRLB (≈1.01–1.02× the bound) |

The current pipeline interpolates the **NSDF/ACF** peak parabolically and the phase‑
vocoder refine partially rescues it, but ~0.1–0.5 ¢ of interpolation bias is on the
table in the very ranges (mid/high) where we want sub‑0.1 ¢.

### 2.3 We discard the partials' information
The current detector estimates *one* fundamental period. But for an 82 Hz string in a
4096‑sample window the fundamental completes only ~7 cycles, while the 10th partial
completes ~70 — and frequency precision scales with cycles observed. The **Cramér‑Rao
lower bound** (Rife–Boorstyn; harmonic form Christensen/Nielsen) makes this exact:

```
single sinusoid:   var(f̂) ≥ 6·fs² / ( (2π)²·SNR·N(N²−1) )
harmonic (P part.): var(f̂0) ≥ 6·fs² / ( (2π)²·SNR·N(N²−1)·Σ A_k² k² )
```

The `Σ A_k² k²` term — dominated by the high partials — is the whole game. Hand‑
computed for our worst case (N=4096, 48 kHz, 82 Hz, 40 dB SNR):

| Estimator | CRLB floor |
|---|---|
| Single‑fundamental | 0.0150 ¢ |
| Harmonic, P=10 | 0.00076 ¢ |
| Harmonic, P=20 + window‑centred index | ~0.00007 ¢ |

**The noise floor is ~0.01 ¢ — two orders of magnitude below where we sit.** We are
nowhere near physics; we are limited by *which estimator we run*. (A free ~16× variance
win, ≈4× in cents, comes purely from indexing the analysis window at its **centre**
rather than its start — Nielsen et al. — a bookkeeping choice, not new compute.)

### 2.4 We never integrate over time
A held tuning note lasts seconds, but we re‑estimate every hop and median/EMA‑smooth.
Fitting a **straight line to unwrapped phase over the whole note** (Tretter's
estimator — provably CRLB‑attaining, variance ∝ 1/T³) is what a mechanical strobe does
optically. Reproduced on the stiff E2:

| Method | clean | 40 dB | 20 dB |
|---|---|---|---|
| ACF + parabolic, fundamental, one 4096 frame | +10.6 ¢ | +10.6 ¢ | +10.2 ¢ |
| **phase‑slope, fundamental, 1.0 s** | −0.044 ¢ | −0.043 ¢ | −0.035 ¢ |
| **phase‑slope, 10 partials, k²‑weighted** | **+0.003 ¢** | +0.003 ¢ | +0.002 ¢ |

Long integration + multi‑partial fusion turns a 10 ¢ problem into a **0.003 ¢** one,
and it gets *more* robust in noise, not less, because the k²‑weighting leans on the
high partials.

### 2.5 Joint (f0, B) recovery is trivially well‑posed
Given partial peaks, `(f_n/n)² = f0²·(1 + B·n²)` is **linear in n²**. A 10‑point least‑
squares fit on the benchmark's own model recovers **f0 to 0.00000 ¢ and B exactly**.
This is the Galembo/Entropy‑Piano‑Tuner method, and it is cheap.

**Conclusion.** The path to "most accurate ever" is not a better single‑pitch trick;
it is (a) **estimate the partials and their inharmonicity jointly**, (b) **interpolate
without bias**, (c) **integrate phase over the held note**, and (d) **be honest about
the sample‑clock floor**. Everything below builds exactly that, while *preserving the
current engine's two crown jewels — 0 % octave errors and ~43 ms acquisition.*

---

## 3. The physical ceiling — what "most accurate ever" can and cannot mean

Two hard floors bound any tuner; we must design to the right side of each.

1. **Noise floor (CRLB).** ~0.01 ¢ in our scenario (§2.3). *Not* our limiter — we
   have two orders of magnitude of headroom. Implication: chase **bias and
   integration**, not SNR.

2. **Sample‑clock floor (absolute pitch only).** A phone computes
   `f = cycles × sample_rate`, using the *nominal* 48 000 Hz; the crystal's true rate
   differs by **±20–100 ppm** (a real measured sound card: 44 ppm). Since
   **1 ¢ = 577.8 ppm**, that is **±0.035–0.17 ¢ of absolute error we cannot see from
   inside the device.** This is *larger than the 0.1 ¢ the strobe apps print.*

   The escape hatch: **relative tuning is immune.** When we compare the input to our
   **own** generated reference tone or strobe reference — both clocked by the *same*
   crystal — the ppm error cancels exactly. So:
   - **Relative / strobe / "match the tone" accuracy → 0.02 ¢ regime, honestly.**
   - **Absolute "is this really 440 Hz" → clock‑bound** unless we calibrate the true
     sample rate (§7.1).

3. **The instrument, not the electronics, usually dominates.** String inharmonicity
   (tens of cents across partials) and **pitch‑glide on decay** (2–5 ¢ typical, up to
   20–25 ¢ on a bad string, mostly in the first 1–1.5 s) swamp a 0.1 ¢ reading. A
   genuinely elite tuner therefore must *manage the string* — measure the settled
   portion, lock on a flat slope, expose inharmonicity — not just polish the math
   (§7.2).

This section is also the **marketing‑honesty spec**: we will claim 0.02 ¢ *relative*,
0.1 ¢ *absolute uncalibrated* (and show why), and ~0.02 ¢ *absolute calibrated* — each
backed by the benchmark, and each more defensible than the unqualified "0.1 ¢" the
competition prints.

---

## 4. Architecture — a precision layer on top of what already works

Keep the current pipeline as the **robust acquisition + octave‑safety + UI‑cadence**
front end (it is excellent at exactly that). Add a **precision refinement stack** that
only ever *sharpens* the acquired estimate — it can never re‑introduce an octave error,
because it searches in a narrow band around an already‑octave‑safe fundamental.

```
                 ┌─────────────────────────── existing, preserved ──────────────────────────┐
 capture ──▶ DC/HPF ──▶ ring ──▶ MPM/NSDF + sustain gate ──▶ octave-safe f0, "what note", clarity
                 └──────────────────────────────────────────────────────────────────────────┘
                                        │  (f0, note, band)
                                        ▼
   ┌──────────────────────────────── NEW precision stack ──────────────────────────────────┐
   │  Spectral core (vDSP rFFT, window-centred)                                             │
   │     → bias-corrected per-partial frequencies (Candan-2013 / Gaussian-log / Goertzel)   │
   │     → joint (f0, B) inharmonic fit  ── Fisher (k²·SNR) weighted fusion ──▶ f0_precise   │
   │     → phase-slope integrator (Tretter) while the note is held ──▶ f0_lock (sub-0.05¢)   │
   │     → uncertainty estimate (σ from the fit) ─────────────────────────────▶ ± precision  │
   └────────────────────────────────────────────────────────────────────────────────────────┘
                                        │  f0_precise / f0_lock, B, ±σ, phase
                                        ▼
              temperament/stretch offsets ──▶ note + cents + strobe phase + precision  ──▶ PitchReading
```

Design rules:
- **Never regress octave safety.** The precision stack's frequency search is clamped to
  ±~50 ¢ around the MPM fundamental. MPM remains the sole authority on *which* octave.
- **Two speeds.** A *snappy* path (per‑hop refine, for the moving phase) and a *lock*
  path (long phase integration, engages when the note is held and stable). The UI
  already distinguishes "tracking" from "locked"; we make the *number* honour it too.
- **Everything is FFT/BLAS‑shaped** → vDSP/Accelerate, real‑time on a phone (the fast‑
  NLS structure is FFT‑class; the per‑partial refine is a handful of Goertzels).
- **Pure and headless.** All new code lands in `PitchPipeline`‑drivable modules with no
  audio device, so the benchmark and tests measure exactly what ships (Plan 01 ethos).

---

## 5. The algorithms, concretely

### 5.1 Spectral core (replaces O(N·maxLag) autocorrelation)
`SpectralAnalyzer` wraps `vDSP_fft_zrip` (real FFT) + `vDSP_create_fftsetup`, cached per
length. Gives the magnitude/complex spectrum once per hop, and a `goertzel(frame, f)`
single‑bin DTFT for off‑grid partial refinement. This both **removes the per‑lag dot‑
product cost** the code already flags as the on‑device optimisation *and* makes long
(8192–16384) windows affordable for the lock path. NSDF can still be derived from the
same FFT (Wiener–Khinchin) so MPM keeps working unchanged.

### 5.2 Bias‑corrected peak frequency (replaces raw parabolic)
`FrequencyInterpolator` with the reproduced ranking: default **Candan‑2013**
`δ = (N/π)·atan( tan(π/N)·Re q )`, `q = (X[k−1]−X[k+1]) / (2X[k]−X[k−1]−X[k+1])`,
with a **Gaussian‑window log‑parabolic** variant (Gasior) and an optional **A&M** 2‑
iteration refine for the few partials that matter most. Expected: the §2.2 0.46 ¢ →
< 0.02 ¢. Keep parabolic only as the NSDF clarity peak (it's fine for confidence).

### 5.3 Harmonic NLS + joint inharmonicity (the centrepiece)
`HarmonicEstimator`:
1. From MPM's `f0`, predict partial locations `f_n = n·f0·√(1+B·n²)` (start B=0).
2. Refine each audible partial's frequency with §5.2 (SNR‑gated; tolerate a missing/
   weak fundamental — common on bass).
3. **Fit (f0, B)** by the linear `(f_n/n)² vs n²` regression (§2.5), one Newton step to
   polish; reject partials with large residuals (anti‑octave, anti‑spurious).
4. **Fuse** the per‑partial f0 estimates by inverse‑variance (Fisher) weights
   `w_n ∝ n²·SNR_n` → `f0_precise` with a closed‑form uncertainty `σ = (Σ w_n)^−½`.
5. Use the **window‑centred time index** throughout (free ~4× cents win).

This is approximate maximum likelihood for the inharmonic‑comb model — the CRLB‑
attaining estimator — and it is where the **bass 2.96 ¢ → ≤1 ¢ and worst 25.7 ¢ → ≤3 ¢**
comes from. Optional later: port the BSD‑3 `fastF0Nls` Toeplitz‑plus‑Hankel solve for
the exact fast‑NLS objective; the harmonic‑summation + regression above gets ~all of the
benefit at a fraction of the code.

### 5.4 Virtual‑strobe lock (long‑window phase integration)
`PhaseIntegrator` extends the existing `StrobePhase`. When the sustain gate reports
**stable** and the note hasn't changed for ≥ K hops, accumulate the unwrapped phase of
each strong partial across the held interval and **least‑squares the slope** (Tretter).
Refer each partial's slope back to f0 via `/(n·√(1+Bn²))` and Fisher‑fuse. Reset on note
change / large jump / silence (the engine already has these transitions). Output:
`f0_lock` with sub‑0.05 ¢ σ (reproduced: 0.003 ¢ at 1 s, 10 partials), *plus* its own
uncertainty so the UI can show "±0.0X ¢". This is the same phase signal the strobe
renders — "the accuracy work and the signature visual are the same work" (DESIGN §3),
now made literally true at strobe precision.

### 5.5 Smoothing/readout
Replace the fixed median+EMA with a **confidence/uncertainty‑aware** blend: while
tracking, the snappy refine drives the moving strobe; on lock, report `f0_lock` and its
σ. The "snap on big jump" behaviour stays (string changes feel instant).

---

## 6. Octave safety — non‑negotiable, and how we keep it at 0 %
- MPM/NSDF remains the *only* octave authority; the precision band is ±50 ¢.
- The harmonic fit **rejects** a partial set whose residuals imply a half/double‑octave
  (a built‑in subharmonic guard — the one documented NLS failure mode).
- Keep an independent cheap **YIN** (already in the codebase) as an octave *vote* on
  low‑SNR frames, exactly as today.
- The benchmark's octave‑error gate stays at **0 %** and fails CI on any regression.

---

## 7. Honesty & calibration — the part nobody else ships

### 7.1 Sample‑rate (clock) calibration → honest absolute accuracy
- Use the **actual** hardware rate everywhere (the capture path already reads
  `format.sampleRate`; thread it through — never hard‑code 48 000 in math).
- Ship an optional **one‑time calibration**: play/record a known reference (or count
  samples against the monotonic clock over ~30–60 s), estimate the per‑device **ppm**
  offset by the FFT‑bin‑centring method (Audio Precision technique), store it, apply it
  as a scalar correction. Re‑offer periodically (crystals drift ~1–2 ppm/day, tens of
  ppm over temperature).
- **Copy that tells the truth:** uncalibrated → "absolute ≤0.2 ¢ (typ. ~0.1 ¢),
  limited by your device's clock; *relative* tuning is exact." Calibrated →
  "absolute ±0.02 ¢."

### 7.2 Decay‑glide handling
- **Skip the attack** (first ~100–250 ms) — it reads sharp.
- **Measure the settled region** (~0.3–1.5 s) where the (f0, B) fit is most stable.
- **Lock on a flat slope**, not a single frame: only show "locked"/green when the
  frequency trend over the last few hundred ms is below a threshold. This rejects both
  the onset overshoot and the decay drift — and it is exactly when the phase‑slope lock
  is valid.

### 7.3 Relative mode = strobe mode
Make "match the reference tone / freeze the strobe" a first‑class, **explicitly clock‑
immune** path. This is the honest road to 0.02 ¢ on commodity hardware and the natural
home for intonation work (where repeatability, not absolute truth, is what matters).

---

## 8. Temperament & inharmonicity — a co‑benefit of the new estimator
Because we now estimate **B** per string, four features fall out almost for free
(engine groundwork here; UI is a later, DESIGN‑sanctioned v2 surface):
- **Stretched / Railsback‑style octave targets** computed from measured B (beat‑free
  octaves and 12th‑fret‑harmonic checks).
- **Sweetened tunings** as editable cents‑offset tables: `target = ET(note) +
  temperament[pitchClass] + sweetener[string] + stretch(note, B)`. Ship Equal, a JI set,
  Peterson‑style GTR/ACU shapes, and True Temperament as presets.
- **Per‑string inharmonicity / "intonation" readout** (a genuinely novel, pro feature:
  no app *shows* you your string's B).
- All of it layered, all of it optional, none of it touching v1's "calm, bare‑bones"
  default (DESIGN §1, §2).

---

## 9. Measurement — proving sub‑0.1 ¢ (do this **first**)
"Measure, don't guess" means the benchmark must be able to *see* the wins before we make
them. Upgrade `BenchmarkSuite`/`CaseRunner`:
- **Longer stimuli** (2–3 s) and a dedicated **lock‑window** score (steady region only),
  separate from the acquisition score.
- **σ (jitter) and worst‑case promoted to headline metrics**, per range.
- **CRLB‑efficiency column**: measured σ ÷ theoretical bound (so we can say "within 1.2×
  of the physical floor").
- **Inharmonic truth is the model f0** (already correct) — and add a per‑partial check
  that B is recovered.
- **New case families**: pluck‑envelope + decay‑glide (the `Synth.applyPluckEnvelope`
  already exists), vibrato/FM, **a weak/missing‑fundamental bass stimulus** (attenuate or
  drop the `k=1` partial — the real low‑B/E DI case the current ∝1/k model never exercises,
  and the one the harmonic estimator is most likely to slip an octave on), and lower
  SNRs (5 dB).
- **Real‑DI fixture harness (lands in P0):** build the loader + scorer for a small set of
  recorded tuned‑string DIs *now*, and validate **B recovery on real low E/B** before any
  sub‑0.1 ¢ / ≤1 ¢ gate is trusted. The recorded audio runs as an **out‑of‑CI** regression
  (CI itself stays synthetic/headless); the point is that the gates measure the *engine*,
  not the synthesizer the P2 estimator is fit to.
- **Tighten CI gates progressively** (`Benchmark --ci`): from today's `abs<10¢,
  octave=0` toward `core abs<0.1¢, σ<0.05¢ (lock), bass abs<1¢, octave=0` — each gate
  ratcheted only after the phase that earns it.

---

## 10. Phased implementation — each gated by the benchmark

Sequence chosen so every phase is independently shippable and *measured*. Tests are
TDD: write the tightened benchmark assertion first, watch it fail, make it pass.

| Phase | Lands | New files | Target it unlocks |
|---|---|---|---|
| **P0 Measure** | benchmark upgrade (§9), CRLB calc, glide/FM + **weak/missing‑fundamental bass** cases, **real‑DI fixture harness** (out‑of‑CI), σ/worst headline, efficiency column | `Bench/Crlb.swift`, `Bench/Fixtures.swift`, extend `Bench/*` | can *see* sub‑0.1 ¢ **on real strings, not just the synth**; gates ready |
| **P1 Spectral + unbiased interp** | vDSP rFFT core; Candan‑2013/Gaussian‑log; window‑centred index; FFT‑based NSDF | `DSP/SpectralAnalyzer.swift`, `DSP/FrequencyInterpolator.swift` | core range 0.2–0.8 ¢ → **≤0.1 ¢**; cheaper |
| **P2 Harmonic NLS + B (centrepiece)** | per‑partial refine, joint (f0,B) fit, Fisher fusion, residual octave guard | `DSP/HarmonicEstimator.swift`, `DSP/Inharmonicity.swift` | bass 2.96/25.7 ¢ → **≤1/≤3 ¢** |
| **P3 Virtual‑strobe lock** | Tretter long‑window phase‑slope, multi‑partial, uncertainty out | `DSP/PhaseIntegrator.swift` (extends `StrobePhase`) | held‑note σ → **≤0.05 ¢**; ± precision in UI |
| **P4 Honesty & calibration** | true‑rate plumbing, ppm calibration, decay‑glide gating, relative/absolute UX + copy | `Capture/ClockCalibration.swift`, app surface | honest **0.02 ¢ rel / 0.1 ¢ abs / 0.02 ¢ calibrated** |
| **P5 Temperament (co‑benefit)** | offset‑table engine, stretch from B, presets; per‑string B readout | `Temperament.swift`, `Stretch.swift` | sweetened/JI/stretched; intonation readout |

P0→P3 are the accuracy core (do in order). P4 is independent and can run in parallel
after P1. P5 is the optional pro layer (DESIGN v2), unlocked by P2.

---

## 11. Public API & app surface (additive, non‑breaking)
`PitchReading` gains (all defaulted, so existing call sites compile):
```swift
public let precisionCents: Double?     // ± uncertainty of `cents` (σ), nil while acquiring
public let inharmonicityB: Double?     // estimated stiffness, nil until the fit converges
public let isLockIntegrated: Bool      // true when `frequency` is the long-integration value
```
`TunerEngine` / `PitchPipeline` gain:
```swift
var precisionMode: PrecisionMode       // .snappy (today) | .strobe (engage long lock)
var temperament: Temperament           // .equal (default) | presets | custom offsets
func calibrateSampleRate() async -> Double   // returns measured ppm; persists per-device
```
App layer (`LiveTunerModel`): show the `± precision` and a "LOCKED ±0.0X ¢" state on the
readout; surface the optional calibration in Settings; temperament/stretch as a v2
Settings surface. The strobe contract (`phase`) is unchanged — it just gets more precise.

---

## 12. Risks & mitigations
- **Octave regression** → precision band clamped to ±50 ¢ of MPM; residual‑based guard;
  YIN vote; CI gate at 0 %. *(Highest‑priority invariant.)*
- **Real strings ≠ the synthetic model** → P0 adds the recorded‑DI fixture harness *and* a
  weak/missing‑fundamental synthetic bass case; validate B recovery on real low E/B before
  trusting the bass numbers (the P2 estimator is fit to the very model the synth generates,
  so a clean recovery against the synth proves little on its own).
- **Latency from long windows** → lock path is opportunistic (only when held); snappy
  path keeps today's ~43 ms acquisition; long FFTs are afforded by the vDSP core.
- **Over‑claiming absolute accuracy** → §7 honesty spec; never print sub‑0.1 ¢ *absolute*
  without calibration; lead with relative/strobe.
- **Scope creep vs. DESIGN §1 "calm, bare‑bones"** → all new UI is opt‑in; the default
  screen is unchanged; temperament/calibration live in Settings.
- **Complexity** → keep MPM acquisition intact; the precision stack is pure, headless,
  and independently benchmarked module‑by‑module.

---

## 13. Prior art & open‑source inspiration

We surveyed the open‑source field for both algorithms and UX. The headline: **LUMA's
current acquisition front end (MPM/NSDF + key‑maxima `k`‑threshold + parabolic + a
"clarity" confidence) is already the algorithm the field considers best for an
instrument tuner** (Tartini/McLeod), and **our single‑bin‑DFT strobe phase is exactly
the technique the best open strobes use** — so this plan *extends* a validated base
rather than replacing it. The new pieces (harmonic NLS, inharmonicity, phase‑slope lock)
are precisely what the surveyed projects either lack or gate behind GPL.

**License hygiene (this is a paid App Store binary — it matters).**
- **Safe to port / ship (MIT/BSD, with attribution):** `fastF0Nls` (**BSD‑3** — the
  CRLB‑attaining harmonic‑NLS estimator, the single most license‑friendly accuracy
  engine), **Tuna** (MIT — a ready collection of sub‑bin FFT interpolators: Quinn 1st/
  2nd, Jain, barycentric), **Beethoven/Pitchy** (MIT — Swift YIN + f0→note/cents),
  **CREPE / torchcrepe / onnxcrepe** (MIT — optional tiny CoreML cross‑check),
  **ZenTuner / SwiftTuner / cwilso PitchDetect** (MIT — capture + UX), **sevagh/pitch‑
  detection** (MIT — clean MPM/YIN/pYIN reimplementations).
- **Reference / study only (GPL/AGPL — do NOT copy into the binary):** aubio (GPLv3),
  pYIN (GPL‑2), Essentia (AGPL‑3), Entropy Piano Tuner (GPLv3), dsego/SonicStrobe &
  billthefarmer/ctuner & x42 tuna.lv2 (GPLv3). The **MPM/NSDF and pYIN/NLS *algorithms*
  are published**, so we implement the methods clean‑room and only *read* the GPL code.

**Ideas we are adopting (mapped to phases):**
1. **fastF0Nls (BSD‑3) → P2.** The NLS/ML harmonic estimator reaches the CRLB, works on
   ~1 period, and its **joint harmonic‑count estimate doubles as an octave/confidence
   check** — port the algorithm for P2's optional exact solver; the harmonic‑summation +
   `(f_n/n)²` regression already gets ~all the benefit with far less code.
2. **pYIN's two‑stage idea → P2/P3 smoothing.** "Emit f0 candidates *with probabilities*,
   then temporally smooth with a Viterbi/HMM (or cheaper **Kalman**) tracker." The field
   calls this *the* biggest stability/octave‑robustness lever after the core estimator —
   a principled upgrade to today's median+EMA. Reimplement (pYIN is GPL).
3. **Tuna's interpolator set (MIT) → P1.** Drop‑in references for `FrequencyInterpolator`
   (Quinn/Jain/barycentric) alongside our chosen Candan‑2013/Gaussian‑log.
4. **dsego/SonicStrobe technique → P3 (already partly ours).** Single‑bin DFT at the
   reference frequency, **inter‑frame phase delta drives the strobe spin**, and **scale
   window/hop by cents (not Hz)** so drift speed is uniform across the range — adopt the
   cents‑scaled hop idea for the integrator. (ctuner/x42 are the overlapped‑FFT and
   delay‑locked‑loop variants of the same phase trick.)
5. **Entropy Piano Tuner (GPL, idea only) → P5.** Per‑string inharmonicity → stretched/
   sweetened targets; the entropy‑of‑superimposed‑partials objective is an expert‑free
   way to derive stretch from measured B.
6. **CREPE‑tiny CoreML (MIT) → optional verifier.** A high‑confidence cross‑check that
   flags ambiguous frames; never the primary low‑latency path (NN latency > NSDF).
7. **AudioKit `ptrack` (MIT) → cautionary tale.** It is FFT‑bin‑limited and the field's
   recurring complaint is exactly **octave errors + jitter on low strings** — the very
   failure LUMA already avoids. Confirms we must *not* regress to spectral‑peak tracking
   for the fundamental; the precision stack only ever *refines* the NSDF fundamental.
8. **UX to borrow (ZenTuner / Tartini, MIT‑safe):** fade the readout by **clarity × RMS**
   so transients/noise don't make the number dance; a single marker that snaps **red→
   green** in tune; tap‑to‑toggle ♯/♭ spelling; one‑tap transposition. These slot into the
   existing LUMA readouts without touching the strobe.

---

## 14. References (curated, all verified during research)

**Estimators & bounds**
- Rife & Boorstyn (1974), *Single‑tone parameter estimation* — the frequency CRLB.
  https://dl.acm.org/doi/10.1109/TIT.1974.1055282
- Christensen & Jakobsson, *Multi‑Pitch Estimation* (2009).
- Nielsen et al. (2017), *Fast fundamental frequency estimation* (statistically efficient
  ↔ FFT‑class). https://www.sciencedirect.com/science/article/abs/pii/S0165168417300117 ·
  code (BSD‑3): https://github.com/jkjaer/fastF0Nls
- de Cheveigné & Kawahara (2002), **YIN**. http://audition.ens.fr/adc/pdf/2002_JASA_YIN.pdf
- McLeod & Wyvill (2005), **MPM/NSDF**. https://quod.lib.umich.edu/i/icmc/bbp2372.2005.107
- Camacho (2008), **SWIPE′**; Mauch & Dixon (2014), **pYIN**; Kim et al. (2018), **CREPE**
  (arXiv:1802.06182) — robustness oracles, not sub‑cent regressors.

**Bias‑corrected interpolation & phase methods**
- JOS/CCRMA, *Quadratic peak interpolation* & *Bias of parabolic peak interpolation*.
  https://ccrma.stanford.edu/~jos/sasp/Quadratic_Interpolation_Spectral_Peaks.html
- Abe & Smith, *QIFFT bias* (STAN‑M‑114). https://ccrma.stanford.edu/files/papers/stanm114.pdf
- Gasior & Gonzalez (CERN), *Gaussian/parabolic spectrum interpolation*.
  https://mgasior.web.cern.ch/pap/FFT_resol_note.pdf
- Candan (2013), *Fine‑resolution frequency from three DFT samples*.
- Aboutanios & Mulgrew (2005), *Iterative interpolation on Fourier coefficients*.
- Tretter (1985) / LSPUE, *frequency by phase‑slope regression* (CRLB‑attaining).
- Betser et al. (2008), *phase‑vocoder / reassignment frequency estimation*.

**Inharmonicity, tuning, glide**
- Fletcher, stiff‑string `f_n=n·f0·√(1+Bn²)`; `B=π³Ed⁴/(64TL²)`; `Δcents≈865.62·B·n²`.
  https://www.acs.psu.edu/drussell/Demos/Stiffness-Inharmonicity/Stiffness-B.html
- Galembo & Askenfelt, *inharmonic comb filters* (IEEE T‑SAP 1999).
- Rauhala, Lehtonen & Välimäki (2007), *Fast automatic inharmonicity estimation*.
  https://pubs.aip.org/asa/jasa/article/121/5/EL184/538552
- *Entropy Piano Tuner* (arXiv:1203.5101). https://arxiv.org/abs/1203.5101
- Peterson Sweeteners; True Temperament tables; Railsback/stretched tuning.
- Pitch‑glide on decay (2–5 ¢ typical, up to ~25 ¢): pitch‑glide analysis refs in notes.

**The accuracy ceiling (strobe & clock)**
- Sonic Research Turbo Tuner FAQ (±0.02 ¢; "limited only by the internal frequency
  generator"). https://www.turbo-tuner.com/pages/faq.htm
- Peterson StroboStomp/iStroboSoft (±0.1 ¢; calibration). https://www.petersontuners.com/
- Audio Precision, *measuring sample‑rate error*.
  https://www.ap.com/news/measuring-sample-rate-error-when-the-sample-clock-is-not-accessible
- Tom Van Baak / leapsecond.com (44 ppm measured sound‑card clock); 1 ¢ = 577.8 ppm.

**Open‑source repos (license in §13)**
- fastF0Nls (BSD‑3): https://github.com/jkjaer/fastF0Nls
- sevagh/pitch‑detection — MIT MPM/YIN/pYIN: https://github.com/sevagh/pitch-detection
- Tuna (MIT, sub‑bin interpolators): https://github.com/alladinian/Tuna ·
  Beethoven/Pitchy (MIT): https://github.com/vadymmarkov/Beethoven
- AudioKit / SoundpipeAudioKit (MIT): https://github.com/AudioKit/AudioKit ·
  ZenTuner (MIT): https://github.com/jpsim/ZenTuner
- CREPE (MIT): https://github.com/marl/crepe · torchcrepe: https://github.com/maxrmorrison/torchcrepe
- Reference‑only (GPL): aubio https://github.com/aubio/aubio · pYIN https://github.com/c4dm/pyin ·
  Entropy Piano Tuner https://gitlab.com/tp3/Entropy-Piano-Tuner ·
  dsego strobe https://github.com/dsego/strobe-tuner · ctuner https://github.com/billthefarmer/ctuner

---

## 15. Definition of done
- Benchmark *measures* (and CI *gates*): core‑range mean ≤ 0.1 ¢, held‑note σ ≤ 0.05 ¢,
  bass mean ≤ 1 ¢ (worst ≤ 3 ¢), octave‑error rate 0.00 %, CRLB‑efficiency reported.
- `docs/benchmarks/accuracy.md` regenerated and quoted in `DESIGN.md §3`.
- Honesty spec shipped: relative 0.02 ¢ / absolute‑uncalibrated ≤0.2 ¢ / calibrated
  0.02 ¢, each with the calibration flow and truthful copy.
- No regression in acquisition latency or octave safety; default UX unchanged.

## 16. Reproduce the diagnosis
The four probes behind §2–§3 (stiff‑string bias, interpolation ladder, CRLB + ppm↔cents,
joint f0/B recovery) are committed, self‑contained Swift and reproduce every cited number
on this repo's toolchain:
```sh
swiftc -O docs/plans/06-accuracy-probes/diagnosis.swift -o /tmp/diag && /tmp/diag
```
See [`06-accuracy-probes/`](06-accuracy-probes/). Fold them into `Bench/` as P0 lands so
the diagnosis itself becomes a CI regression test.

---

## Kickoff prompt (Phase P0 — do this first)
> Read `DESIGN.md` (§1, §3), `docs/plans/06-accuracy-engine.md`, and the current
> `Packages/TunerEngine` benchmark (`Bench/*`, `docs/benchmarks/accuracy.md`). Implement
> **Phase P0**: upgrade the accuracy benchmark to measure σ (jitter), worst‑case, and a
> CRLB‑efficiency column at the sub‑0.1 ¢ level; add longer (2–3 s) stimuli with a
> separate lock‑window score; add pluck‑envelope/decay‑glide, vibrato, **a weak/missing‑
> fundamental bass stimulus (attenuated/dropped `k=1` — the real low‑string case the ∝1/k
> model never exercises)**, and 5 dB SNR case families; add a hand‑checked CRLB calculator
> (`Bench/Crlb.swift`), a **real‑DI fixture harness (`Bench/Fixtures.swift`: loader +
> scorer, recorded audio out‑of‑CI)**, and the four §16 diagnosis probes as regression
> tests. Tighten the `--ci` gate only as far as today's
> numbers safely allow, and leave TODO gates for P1–P3. No engine behaviour change yet —
> this phase only makes the wins *measurable*.
