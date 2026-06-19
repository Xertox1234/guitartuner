---
title: "vDSP is subordinate to the zero-delta proof: vectorizing a reduction reorders summation; spend the re-baseline only where the perf win is real"
track: knowledge
category: best-practices
tags: [dsp, pipeline, testing]
module: TunerEngine
applies_to: ["Packages/TunerEngine/Sources/TunerEngine/DSP/PhaseIntegrator.swift", "Packages/TunerEngine/Sources/TunerEngine/DSP/*.swift"]
created: 2026-06-18
---

## When this applies

You are tempted to apply `docs/rules/dsp.md` ("Use Accelerate/vDSP for all
inner-loop math; no hand-rolled loops where `vDSP_*` equivalents exist") to a
small **reduction** (sum / mean / dot product) that sits on a **CI-gated DSP
path** — one whose output flows into the accuracy benchmark. The motivating case
is `PhaseIntegrator.lsSlope` (`reduce(0,+)` means and `.map { $0 - mean }`
centering, ~lines 261-266). Closed WON'T-DO in PR #48
(`docs/todos/archive/P3-phaseintegrator-lsslope-scalar.md`).

## The principle

**The vDSP rule is subordinate to the zero-delta requirement, not the other way
around.** For a refactor on an accuracy-gated path we require a zero-delta proof:
regenerate `accuracy.csv` at the pre-change commit and at HEAD (same machine,
same vDSP path, pinned `--date`), then diff — it must be **byte-identical**
(`accuracy.csv` is gitignored, so the proof is a same-platform regenerate-and-diff,
not a committed-file diff; see `P3-nextband-identity-not-label-match.md`).

A floating-point reduction is **not bit-preserving** when you change how it is
summed:

- `reduce(0, +)` sums strictly left-to-right.
- `vDSP_meanvD` (and pairwise / SIMD-lane summation generally) sums in a
  different order. Different order → different rounding → different bits.

On a byte-identical gate, "the difference is tiny, it rounds away" is **not an
available defense**: the requirement is byte-identical, so the burden is to prove
the bits *don't* change, and for a reduction reorder you cannot. The honest cost
of vectorizing a reduction here is "re-baseline the benchmark and re-prove the
spec." **Pay that only where the perf win justifies it.**

For `lsSlope`'s means: arrays are `k ≤ 140` (`PhaseIntegrator.maxHops`) and the
function runs only on stable sustain (off the hot path) — **no measurable win**,
so nothing justifies the re-baseline. Leave them scalar.

## Why this is coherent with the dot products already in `lsSlope`

`lsSlope` *already* vectorizes three reductions (`vDSP_dotprD` ×2 for `sxy`/`sxx`,
`vDSP_vsmaD`→`vDSP_dotprD` for the SSE), committed in `c85720e`. That is **not a
contradiction** — it is the asymmetry the rule is about:

- The dot products are the **dominant arithmetic** (O(k) multiply-adds, the actual
  work of the LS fit) — a real win, so paying the re-baseline cost was justified.
- The means/centering are trivial scalar passes — no win, so the cost is not
  justified.

`c85720e` modified only the two `.swift` files (it could not "change the CSV" —
the CSV isn't committed); the perf win lived in the dot products, which is exactly
where the rule says to spend the cost.

## Two measured facts that pin the framing (arm64, Apple Swift 6.3, `swiftc -O`)

1. **`vDSP_meanvD` reorders summation and it propagates to the emitted estimate.**
   On 20 000 realistic `times`/`phases` histories (`k ∈ {20,50,90,140}`,
   bass hop `dt = 1024/48000 s`): the mean differed from `reduce(0,+)/k` in **68 %**
   of cases (up to **~282 ULP**), and that propagated to a **bit-different LS slope
   in ~19 %** of cases. So the change is *not* "~1 ULP that rounds away" — it
   reaches `slope → f_n → f0Lock → r.f0`, which feeds `emittedFrequency`
   (`PitchPipeline.swift:239`, inside `if isLockIntegrated`) and `precisionCents`.

2. **Element-wise centering `a + (-mean)` IS bit-identical to `a - mean`.**
   2.4 M random cases, **zero** mismatches. This is definitional: IEEE 754 defines
   `a − b` as `a + (−b)`, negation is exact, and `vDSP_vsaddD` is a single
   **non-fused** add per element (no reorder). So `vDSP_vsaddD(a, &negMean, …)`
   centering *would* be safe on its own.

   The reason to leave centering scalar anyway is **clarity, not correctness**:
   half-vectorizing the function (vDSP centering while the means stay scalar) is
   worse to read than a consistent scalar block, for zero benefit.

## Scope caution: do NOT generalize "vDSP element-wise is bit-safe"

The bit-safety in fact #2 is specific to **non-fused** element-wise ops
(`vsadd`/`vsub`). It does **not** extend to fused-multiply-add ops. Measured: the
existing `vDSP_vsmaD` residual path (`A·(−slope) + dp`) is **NOT** bit-identical
to the scalar fallback `dp[i] − slope*dt[i]` — it differed in **>99 %** of
residual vectors and **80 %** of SSE values (vDSP uses an FMA; the scalar form
rounds twice). Practical consequence: the **`#else` scalar fallback (Linux CI) and
the Accelerate path (macOS) already produce different bits** for the SSE/sigma.
The zero-delta proof is therefore necessarily **path-local** — same platform,
vDSP-vs-vDSP (or scalar-vs-scalar) — never vDSP-vs-scalar across platforms. Treat
the committed vDSP path as the source of truth and prove zero-delta against
*itself* at the prior commit.

## Rule of thumb

On a CI-gated DSP path: a `vDSP_*` reduction (sum/mean/dotprod) reorders
summation and is **not bit-preserving** — vectorize it only where the perf win is
real enough to justify re-baselining the accuracy spec. Element-wise non-fused
ops (`vsadd`/`vsub`) are bit-preserving; FMA ops (`vsma`) are not. Off-hot-path
scalar reductions over tiny arrays (here `k ≤ 140`) are correct to leave alone.

## Related

- `docs/rules/dsp.md` (qualifies the "use vDSP everywhere" line)
- `docs/todos/archive/P3-phaseintegrator-lsslope-scalar.md` (the WON'T-DO record)
- [[phase-integrator-precision-gate-guards-emission-2026-06-15]] (proves the chain
  to `emittedFrequency`)
- `docs/todos/archive/P3-nextband-identity-not-label-match.md` (the
  regenerate-and-diff zero-delta methodology)
