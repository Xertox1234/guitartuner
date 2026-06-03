# Accuracy benchmarks

The measured-accuracy spec for `TunerEngine` (DESIGN §3 — *"we publish the spec
from measured data, not guesses"*).

- **`accuracy.md`** — the human-readable report (headline numbers, by signal type,
  by range, noise robustness, octave safety, the window/hop table). Committed here
  (populated from a real macOS CI run) and quoted in DESIGN §3.
- **`accuracy.csv`** — every benchmark case, machine-readable. Produced by
  `--out` and uploaded as the CI `accuracy-report` artifact (not committed, to keep
  the diff small); regenerate locally any time.

## Regenerate

```sh
swift run -c release --package-path Packages/TunerEngine Benchmark \
  --compare --out docs/benchmarks
```

Deterministic (seeded noise), so numbers are reproducible. CI runs the benchmark
on every push (`--ci` fails the build on gross regressions: any clean-tone octave
error, clean abs error > 10 ¢, or median cold-start lock > 350 ms) and uploads the
report as an artifact. These files are committed from a real CI run.

## What it measures

Synthesized **pure**, **harmonic**, and **inharmonic string** tones (stiff-string
law `f_k = k·f0·√(1+B·k²)` — the case that biases naive spectral-peak trackers
sharp) across the full guitar+bass range (low B ~31 Hz → ~E6) at known cents, plus
white-noise SNR sweeps. Metrics: cents error (mean / abs / σ) vs the true
frequency, time-to-lock, octave-error rate, and robustness vs SNR.

Recorded-DI samples (real strings through an interface) are a planned addition;
the file-input path (`AVAudioFile`) is already exercised by the tests, so dropping
in real recordings is straightforward.
