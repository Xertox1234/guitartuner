# TunerEngine — measured accuracy

_Generated 2026-06-03T18:20:02Z. Method: **MPM**, 48000 Hz, A4 = 440 Hz. Deterministic (seeded)._

> Measured on macOS CI (`swift run -c release Benchmark`) at commit `6414414` —
> regenerate locally with `swift run -c release --package-path Packages/TunerEngine Benchmark --out docs/benchmarks`.

## Headline

| Metric | Value |
|---|---|
| Mean abs cents error (clean) | **1.42¢** |
| Jitter σ (clean) | 3.31¢ |
| Worst-case abs error (clean) | 25.71¢ |
| Octave-error rate (clean) | 0.00% |
| Median time-to-lock (cold start) | 43 ms |
| Cases | 207 |

## By signal type (clean)

| Signal | n | mean ¢ | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|---|
| pure | 2208 | 0.19 | 0.90 | 2.26 | 15.49 |
| harmonic | 2208 | -0.90 | 1.65 | 3.75 | 24.74 |
| inharmonic | 2236 | -0.21 | 1.70 | 3.61 | 25.71 |

## By range (clean)

| Range | n | abs ¢ | σ ¢ | max ¢ |
|---|---|---|---|---|
| bass (<82 Hz) | 2472 | 2.96 | 5.22 | 25.71 |
| mid (82–330 Hz) | 2236 | 0.76 | 1.33 | 9.52 |
| high (>330 Hz) | 1944 | 0.22 | 0.36 | 2.58 |

## Noise robustness (inharmonic, abs cents vs SNR)

| SNR (dB) | n | abs ¢ | σ ¢ | octave errors |
|---|---|---|---|---|
| 40 | 132 | 0.76 | 1.06 | 0 |
| 20 | 132 | 0.74 | 1.07 | 0 |
| 10 | 132 | 0.86 | 1.12 | 0 |

## Octave safety on low strings (clean, 0¢)

| Note | true Hz | abs ¢ | octave error |
|---|---|---|---|
| B0 | 30.87 | 11.53 | no |
| E1 | 41.20 | 1.41 | no |
| A1 | 55.00 | 2.03 | no |
| D2 | 73.42 | 0.97 | no |
| G2 | 98.00 | 0.55 | no |

## Window / hop strategy (48 kHz)

| Band | f0 | Window | Hop | Overlap |
|---|---|---|---|---|
| high | ≥250 Hz | 1024 (21 ms) | 256 (5.3 ms) | 75% |
| mid | 120–250 Hz | 2048 (43 ms) | 512 (11 ms) | 75% |
| low | <120 Hz | 4096 (85 ms) | 1024 (21 ms) | 75% |
| acquire (cold) | unknown | 4096 (85 ms) | 1024 (21 ms) | 75% |

## Method

Each case synthesizes ~0.6–1.2 s of tone at a known frequency, feeds it through a fresh `PitchPipeline` in ~10 ms blocks, and scores the **steady-state** readings (after 300 ms, skipping the acquisition transient). Cents error is signal-relative (`1200·log₂(estimate/true)`), not quantised to the nearest note. Time-to-lock is cold-start (first confident reading within ±5¢; the timestamp is the analysed window's centre); warm per-hop latency is the hop size above. Inharmonic tones use the stiff-string law `f_k = k·f0·√(1+B·k²)`, the case naive spectral-peak trackers fail. Numbers are reproducible via `swift run Benchmark`.

---

### Reading the numbers

- **No octave errors** anywhere across 207 cases (pure / harmonic / inharmonic, full range, plus SNR sweeps) — including 5-string **low B (30.87 Hz)**. This is the headline robustness result: MPM/NSDF tracks the fundamental, not the tallest partial.
- **Sub-cent in the mid/high range** (abs 0.76¢ / 0.22¢), which covers most of the guitar. Worst-case error sits at the extreme-detuned **low bass** (~26¢ at ±50¢ on the lowest notes), where only ~2–3 periods fit the window — expected, and far from an octave.
- **Noise-robust:** essentially unchanged from 40 dB down to **10 dB SNR** (abs ~0.8¢, zero octave errors), because the periodicity gate rides through broadband noise.
- **Fast:** median cold-start lock at the first analysis window (~43 ms centre); the lowest strings settle later (longer window) as designed.
