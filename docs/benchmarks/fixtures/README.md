# Real-DI fixtures (out-of-CI)

Drop a small set of **recorded tuned-string DIs** here to validate the engine on
*real* strings — not just the synthetic stiff-string model the benchmark
generates (and that P2's harmonic estimator is fit to). This is the harness Plan
06 §9/§12 calls for: the synthetic gates can confirm the math, but only real
audio confirms the engine.

**This directory is intentionally empty in git** (audio is large and binary). CI
stays synthetic/headless; fixtures are an **out-of-CI** regression a developer
runs locally.

## Usage

```sh
swift run -c release --package-path Packages/TunerEngine Benchmark \
  --fixtures docs/benchmarks/fixtures
```

The harness loads every `*.wav`, scores it through the *same* `CaseRunner` as the
synthetic benchmark (abs cents, σ, held-note lock σ, worst-case, octave safety),
and prints a table. Missing/empty dir → skipped silently.

## Naming convention (the filename encodes the truth)

- `<note>.wav` — e.g. `E2.wav`, `A2.wav`, `Bb1.wav`, `B0.wav`. The true frequency
  is the equal-tempered note at A4 = 440 (scientific octave: A4 → octave 4).
- `<label>_<trueHz>.wav` — e.g. `lowB_30.87.wav`, `E2_82.41.wav` — when you want
  an exact measured target rather than the nominal note.

## Recording tips

- **Wired DI**, mono, ideally 48 kHz. PCM 16/24/32-bit or float32 are all read.
- Record a **held, sustained** note (≥ ~2 s) so the lock window (after 1.0 s) has
  signal; trim leading silence.
- Prioritise the **low strings** (B0/E1/A1/E2) and a **weak/missing-fundamental**
  pluck — the cases the synthetic model can't fully stand in for, and where P2's
  bass and B-recovery claims must be proven.
