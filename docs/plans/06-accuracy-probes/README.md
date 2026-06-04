# Plan 06 — diagnosis probes

Self-contained, runnable evidence for [`../06-accuracy-engine.md`](../06-accuracy-engine.md)
§2–§3. Reproduces every number the plan's diagnosis rests on, on the repo's Swift
toolchain — no package, no audio device. "Measure, don't guess" (DESIGN §3).

```sh
swiftc -O docs/plans/06-accuracy-probes/diagnosis.swift -o /tmp/diag && /tmp/diag
```

What each probe shows (expected output):

| Probe | Demonstrates | Headline result |
|---|---|---|
| **A** | single-fundamental estimation leaves inharmonicity bias on the table; long phase integration + multi-partial fusion removes it | ACF+parabolic **+10.6 ¢** → phase-slope **−0.044 ¢** → 10-partial k² **+0.003 ¢** (and *more* noise-robust) |
| **B** | raw parabolic peak interpolation is biased | linear-mag **0.457 ¢** (= 5.3 % of a bin) vs log-mag **0.139 ¢** |
| **C** | the noise floor (CRLB) is ~100× below where we sit; the absolute floor is the sample clock | CRLB **0.015 ¢** single / **0.0008 ¢** harmonic-P10; **1 ¢ = 577.8 ppm**; 100 ppm = **0.17 ¢** |
| **D** | joint (f0, B) is trivially well-posed; the benchmark's 25.7 ¢ worst case *is* the 10th-partial sharpness | f0 recovered to **0.00000 ¢**, B exact; n=10 sharpness **25.97 ¢** |

Phase **P0** of the plan folds these into the package's `Bench/` suite as regression
tests, so the diagnosis becomes part of CI rather than a one-off.
