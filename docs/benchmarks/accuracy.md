# TunerEngine — measured accuracy

_Generated 2026-06-14T23:07:14Z. Method: **MPM**, 48000 Hz, A4 = 440 Hz. Deterministic (seeded)._

> Regenerate: `swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks`. CI (macOS) regenerates this every build as an artifact; this committed copy is the published spec.

## Headline

| Metric | Value |
|---|---|
| Mean abs cents error (clean) | **0.23¢** |
| Jitter σ (clean, steady) | 0.41¢ |
| **Held-note lock-window σ (clean)** | 0.42¢ |
| Worst-case abs error (clean) | 3.94¢ |
| Octave-error rate (clean) | 0.00% |
| Median time-to-lock (cold start) | 43 ms |
| Clean cases / stress cases | 195 / 15 |

## By signal type (clean)

| Signal | n | mean ¢ | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|---|
| pure | 10525 | -0.00 | 0.07 | 0.19 | 1.61 |
| harmonic | 10525 | 0.02 | 0.27 | 0.53 | 3.94 |
| inharmonic | 10525 | 0.21 | 0.34 | 0.41 | 3.46 |

## By range (clean) — steady vs held-note lock window

| Range | n | abs ¢ | σ ¢ | max ¢ | lock abs ¢ | lock σ ¢ |
|---|---|---|---|---|---|---|
| bass (<82 Hz) | 6762 | 0.51 | 0.79 | 3.94 | 0.49 | 0.78 |
| mid (82–330 Hz) | 13401 | 0.19 | 0.23 | 1.61 | 0.18 | 0.22 |
| high (>330 Hz) | 11412 | 0.11 | 0.13 | 0.64 | 0.11 | 0.14 |

## Stress cases (reported, not pooled into the headline)

Real-world realities the default model omits — the families P1–P3 must improve. Today they run on the current engine as a baseline.

| Family | n | abs ¢ | σ ¢ | lock σ ¢ | max ¢ | octave err |
|---|---|---|---|---|---|---|
| weak-fund | 348 | 0.36 | 0.45 | 0.43 | 1.60 | 0 |
| missing-fund | 348 | 0.36 | 0.45 | 0.40 | 1.57 | 0 |
| decay-glide | 704 | 4.21 | 3.37 | 1.02 | 14.07 | 0 |
| vibrato | 617 | 14.86 | 16.96 | 16.89 | 27.31 | 0 |

## Noise robustness (inharmonic, abs cents vs SNR)

| SNR (dB) | n | abs ¢ | σ ¢ | lock σ ¢ | octave errors |
|---|---|---|---|---|---|
| 40 | 628 | 0.29 | 0.21 | 0.19 | 0 |
| 20 | 628 | 0.28 | 0.26 | 0.24 | 0 |
| 10 | 628 | 0.45 | 0.54 | 0.54 | 0 |
| 5 | 628 | 0.70 | 0.87 | 0.89 | 0 |

## CRLB floor & efficiency (held E2, N=4096)

Physical limit (single-tone vs harmonic, ∝1/k weight 6.45), and the measured held-note σ as a multiple of it. The quiet-signal gap to the floor is the P2/P3 headroom, now visible. (The bound is per *single* N=4096 window; the measured lock σ comes after median+EMA smoothing, which integrates across windows — so at very low SNR it can legitimately sit below the single-window floor.)

| SNR (dB) | CRLB σ single ¢ | CRLB σ harmonic ¢ | measured lock σ ¢ | σ / harmonic floor |
|---|---|---|---|---|
| 40 | 0.0212 | 0.0083 | 0.007 | 0.8× |
| 20 | 0.2121 | 0.0835 | 0.053 | 0.6× |
| 10 | 0.6706 | 0.2640 | 0.158 | 0.6× |
| 5 | 1.1926 | 0.4695 | 0.284 | 0.6× |

_Absolute-pitch clock floor: a device sample clock off by N ppm reads `1200·log₂(1+N/10⁶)` ¢ sharp — 44 ppm ≈ 0.076¢, 100 ppm ≈ 0.173¢ (1 ¢ = 578 ppm). Relative/strobe tuning is clock-immune; absolute is clock-bound until calibrated (Plan 06 §3, §7; P4)._

## Octave safety on low strings (clean, 0¢)

| Note | true Hz | abs ¢ | octave error |
|---|---|---|---|
| B0 | 30.87 | 2.10 | no |
| E1 | 41.20 | 0.56 | no |
| A1 | 55.00 | 0.58 | no |
| D2 | 73.42 | 0.41 | no |
| G2 | 98.00 | 0.21 | no |

## Window / hop strategy (48 kHz)

| Band | f0 | Window | Hop | Overlap |
|---|---|---|---|---|
| high | ≥250 Hz | 1024 (21 ms) | 256 (5.3 ms) | 75% |
| mid | 120–250 Hz | 2048 (43 ms) | 512 (11 ms) | 75% |
| low | <120 Hz | 4096 (85 ms) | 1024 (21 ms) | 75% |
| acquire (cold) | unknown | 4096 (85 ms) | 1024 (21 ms) | 75% |

## Method

Each case synthesizes ~2–2.6 s of tone at a known frequency, feeds it through a fresh `PitchPipeline` in ~10 ms blocks, and scores the **steady-state** readings (after 300 ms). The **lock window** scores only the later, held region (after 1.0 s) — where a strobe-grade tuner should drive σ to the noise floor; P3's phase-slope integrator is what earns it. Cents error is signal-relative (`1200·log₂(estimate/true)`), not quantised to the nearest note. Inharmonic tones use the stiff-string law `f_k = k·f0·√(1+B·k²)`. The CRLB is the Cramér–Rao floor (Rife–Boorstyn / Christensen); see `Bench/Crlb.swift`. Numbers are reproducible via `swift run Benchmark`.
