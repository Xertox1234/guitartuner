# TunerEngine — measured accuracy

_Generated 2026-06-04T10:49:05Z. Method: **MPM**, 48000 Hz, A4 = 440 Hz. Deterministic (seeded)._

> Regenerate: `swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks`. CI (macOS) regenerates this every build as an artifact; this committed copy is the published spec.

## Headline

| Metric | Value |
|---|---|
| Mean abs cents error (clean) | **1.02¢** |
| Jitter σ (clean, steady) | 2.60¢ |
| **Held-note lock-window σ (clean)** | 2.74¢ |
| Worst-case abs error (clean) | 25.89¢ |
| Octave-error rate (clean) | 0.00% |
| Median time-to-lock (cold start) | 43 ms |
| Clean cases / stress cases | 195 / 15 |

## By signal type (clean)

| Signal | n | mean ¢ | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|---|
| pure | 10525 | 0.01 | 0.55 | 1.48 | 15.49 |
| harmonic | 10525 | -0.51 | 1.18 | 3.01 | 25.50 |
| inharmonic | 10685 | 0.47 | 1.32 | 2.92 | 25.89 |

## By range (clean) — steady vs held-note lock window

| Range | n | abs ¢ | σ ¢ | max ¢ | lock abs ¢ | lock σ ¢ |
|---|---|---|---|---|---|---|
| bass (<82 Hz) | 6762 | 2.98 | 5.33 | 25.89 | 3.03 | 5.35 |
| mid (82–330 Hz) | 13561 | 0.70 | 1.15 | 9.52 | 0.68 | 1.09 |
| high (>330 Hz) | 11412 | 0.23 | 0.40 | 4.91 | 0.23 | 0.37 |

## Stress cases (reported, not pooled into the headline)

Real-world realities the default model omits — the families P1–P3 must improve. Today they run on the current engine as a baseline.

| Family | n | abs ¢ | σ ¢ | lock σ ¢ | max ¢ | octave err |
|---|---|---|---|---|---|---|
| weak-fund | 348 | 12.28 | 15.16 | 15.24 | 44.29 | 0 |
| missing-fund | 348 | 29.30 | 30.61 | 30.66 | 45.99 | 0 |
| decay-glide | 704 | 4.55 | 3.82 | 1.76 | 15.18 | 0 |
| vibrato | 617 | 13.85 | 16.03 | 15.96 | 27.46 | 0 |

## Noise robustness (inharmonic, abs cents vs SNR)

| SNR (dB) | n | abs ¢ | σ ¢ | lock σ ¢ | octave errors |
|---|---|---|---|---|---|
| 40 | 628 | 0.57 | 0.76 | 0.84 | 0 |
| 20 | 628 | 0.57 | 0.76 | 0.83 | 0 |
| 10 | 628 | 0.64 | 0.81 | 0.87 | 0 |
| 5 | 628 | 0.77 | 1.04 | 1.14 | 0 |

## CRLB floor & efficiency (held E2, N=4096)

Physical limit (single-tone vs harmonic, ∝1/k weight 6.45), and the measured held-note σ as a multiple of it. Today's σ sits far above the floor — that gap is the P2/P3 headroom, now visible.

| SNR (dB) | CRLB σ single ¢ | CRLB σ harmonic ¢ | measured lock σ ¢ | σ / harmonic floor |
|---|---|---|---|---|
| 40 | 0.0150 | 0.0059 | 0.281 | 48× |
| 20 | 0.1500 | 0.0590 | 0.300 | 5.1× |
| 10 | 0.4742 | 0.1867 | 0.412 | 2.2× |
| 5 | 0.8433 | 0.3320 | 0.437 | 1.3× |

_Absolute-pitch clock floor: a device sample clock off by N ppm reads `1200·log₂(1+N/10⁶)` ¢ sharp — 44 ppm ≈ 0.076¢, 100 ppm ≈ 0.173¢ (1 ¢ = 578 ppm). Relative/strobe tuning is clock-immune; absolute is clock-bound until calibrated (Plan 06 §3, §7; P4)._

## Octave safety on low strings (clean, 0¢)

| Note | true Hz | abs ¢ | octave error |
|---|---|---|---|
| B0 | 30.87 | 11.89 | no |
| E1 | 41.20 | 1.48 | no |
| A1 | 55.00 | 2.62 | no |
| D2 | 73.42 | 1.30 | no |
| G2 | 98.00 | 0.73 | no |

## Window / hop strategy (48 kHz)

| Band | f0 | Window | Hop | Overlap |
|---|---|---|---|---|
| high | ≥250 Hz | 1024 (21 ms) | 256 (5.3 ms) | 75% |
| mid | 120–250 Hz | 2048 (43 ms) | 512 (11 ms) | 75% |
| low | <120 Hz | 4096 (85 ms) | 1024 (21 ms) | 75% |
| acquire (cold) | unknown | 4096 (85 ms) | 1024 (21 ms) | 75% |

## Method

Each case synthesizes ~2–2.6 s of tone at a known frequency, feeds it through a fresh `PitchPipeline` in ~10 ms blocks, and scores the **steady-state** readings (after 300 ms). The **lock window** scores only the later, held region (after 1.0 s) — where a strobe-grade tuner should drive σ to the noise floor; P3's phase-slope integrator is what earns it. Cents error is signal-relative (`1200·log₂(estimate/true)`), not quantised to the nearest note. Inharmonic tones use the stiff-string law `f_k = k·f0·√(1+B·k²)`. The CRLB is the Cramér–Rao floor (Rife–Boorstyn / Christensen); see `Bench/Crlb.swift`. Numbers are reproducible via `swift run Benchmark`.
