# TunerEngine — measured accuracy

_Generated 2026-06-20T21:09:51Z. Method: **MPM**, 48000 Hz, A4 = 440 Hz. Deterministic (seeded)._

> Regenerate: `swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks`. CI regenerates this on every build in the Linux `engine` job and uploads it as the `accuracy-report` artifact; this committed copy is the published spec — refresh it from that artifact, not a local run.

## Headline

| Metric | Value |
|---|---|
| Mean abs cents error (clean) | **0.10¢** |
| Jitter σ (clean, steady) | 0.15¢ |
| **Held-note lock-window σ (clean)** | 0.12¢ |
| Worst-case abs error (clean) | 1.72¢ |
| Octave-error rate (clean) | 0.00% |
| Median time-to-lock (cold start) | 43 ms |
| Clean cases / stress cases | 195 / 15 |

## By signal type (clean)

| Signal | n | mean ¢ | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|---|
| pure | 10201 | -0.00 | 0.01 | 0.07 | 1.41 |
| harmonic | 10255 | 0.01 | 0.02 | 0.10 | 1.72 |
| inharmonic | 10255 | 0.26 | 0.27 | 0.07 | 1.33 |

## By range (clean) — steady vs held-note lock window

| Range | n | abs ¢ | σ ¢ | max ¢ | lock abs ¢ | lock σ ¢ |
|---|---|---|---|---|---|---|
| bass (<82 Hz) | 5898 | 0.13 | 0.20 | 1.72 | 0.10 | 0.13 |
| mid (82–330 Hz) | 13401 | 0.09 | 0.13 | 1.16 | 0.09 | 0.12 |
| high (>330 Hz) | 11412 | 0.09 | 0.12 | 0.27 | 0.09 | 0.12 |

## Stress cases (reported, not pooled into the headline)

Real-world realities the default model omits — the families P1–P3 must improve. Today they run on the current engine as a baseline.

| Family | n | abs ¢ | σ ¢ | lock σ ¢ | max ¢ | octave err |
|---|---|---|---|---|---|---|
| weak-fund | 303 | 0.33 | 0.26 | 0.21 | 1.08 | 0 |
| missing-fund | 303 | 0.28 | 0.27 | 0.27 | 0.55 | 0 |
| decay-glide | 704 | 9.47 | 2.36 | 1.89 | 14.77 | 0 |
| vibrato | 617 | 0.95 | 3.75 | 0.04 | 27.03 | 0 |

## Noise robustness (inharmonic, abs cents vs SNR)

| SNR (dB) | n | abs ¢ | σ ¢ | lock σ ¢ | octave errors |
|---|---|---|---|---|---|
| 40 | 628 | 0.27 | 0.08 | 0.01 | 0 |
| 20 | 628 | 0.27 | 0.09 | 0.01 | 0 |
| 10 | 628 | 0.27 | 0.09 | 0.01 | 0 |
| 5 | 628 | 0.27 | 0.11 | 0.03 | 0 |

## Bass policy (bass notes under `.bass`)

Bass strings driven through the **`.bass`** DetectionPolicy (the rest of the report uses `.fullRange`). Lock retention = fraction of held-window frames holding the phase-integrator lock; drops = mid-sustain lock losses. This is the bass-settling signal the Phase 4 gate reads.

| Family | n | abs ¢ | lock σ ¢ | lock retention | lock drops |
|---|---|---|---|---|---|
| bass-clean | 241 | 0.24 | 0.02 | 100.00% | 0 |
| bass-weak-fund | 241 | 0.25 | 0.13 | 98.29% | 0 |

## CRLB floor & efficiency (held E2, N=4096)

Physical limit (single-tone vs harmonic, ∝1/k weight 6.45), and the measured held-note σ as a multiple of it. The quiet-signal gap to the floor is the P2/P3 headroom, now visible. (The bound is per *single* N=4096 window; the measured lock σ comes after median+EMA smoothing, which integrates across windows — so at very low SNR it can legitimately sit below the single-window floor.)

| SNR (dB) | CRLB σ single ¢ | CRLB σ harmonic ¢ | measured lock σ ¢ | σ / harmonic floor |
|---|---|---|---|---|
| 40 | 0.0212 | 0.0083 | 0.002 | 0.3× |
| 20 | 0.2121 | 0.0835 | 0.004 | 0.0× |
| 10 | 0.6706 | 0.2640 | 0.006 | 0.0× |
| 5 | 1.1926 | 0.4695 | 0.011 | 0.0× |

_Absolute-pitch clock floor: a device sample clock off by N ppm reads `1200·log₂(1+N/10⁶)` ¢ sharp — 44 ppm ≈ 0.076¢, 100 ppm ≈ 0.173¢ (1 ¢ = 578 ppm). Relative/strobe tuning is clock-immune; absolute is clock-bound until calibrated (Plan 06 §3, §7; P4)._

## Octave safety on low strings (clean, 0¢)

| Note | true Hz | abs ¢ | octave error |
|---|---|---|---|
| B0 | 30.87 | 0.18 | no |
| E1 | 41.20 | 0.33 | no |
| A1 | 55.00 | 0.30 | no |
| D2 | 73.42 | 0.28 | no |
| G2 | 98.00 | 0.26 | no |

## Window / hop strategy (48 kHz)

| Band | f0 | Window | Hop | Overlap |
|---|---|---|---|---|
| high | ≥250 Hz | 1024 (21 ms) | 256 (5.3 ms) | 75% |
| mid | 120–250 Hz | 2048 (43 ms) | 512 (11 ms) | 75% |
| low | 40–120 Hz | 4096 (85 ms) | 1024 (21 ms) | 75% |
| ultralow | <40 Hz (5-str low B) | 8192 (170 ms) | 2048 (43 ms) | 75% |
| acquire (cold) | unknown | 4096 (85 ms) | 1024 (21 ms) | 75% |

## Method

Each case synthesizes ~2–2.6 s of tone at a known frequency, feeds it through a fresh `PitchPipeline` in ~10 ms blocks, and scores the **steady-state** readings (after 300 ms). The **lock window** scores only the later, held region (after 1.0 s) — where a strobe-grade tuner should drive σ to the noise floor; P3's phase-slope integrator is what earns it. Cents error is signal-relative (`1200·log₂(estimate/true)`), not quantised to the nearest note. Inharmonic tones use the stiff-string law `f_k = k·f0·√(1+B·k²)`. The CRLB is the Cramér–Rao floor (Rife–Boorstyn / Christensen); see `Bench/Crlb.swift`. Numbers are reproducible via `swift run Benchmark`.
