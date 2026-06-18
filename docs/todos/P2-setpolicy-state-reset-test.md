---
priority: P2
status: open
domain: testing, pipeline
source: 2026-06-17 instrument-profiles Slice 1 review (Task 6)
---

# Test `PitchPipeline.setPolicy` actually resets detection state on swap

**Severity:** Medium
**Source:** 2026-06-17 instrument-profiles Slice 1 — Task 6 code-quality review (deferred), confirmed by advisor.
**Domain:** testing, pipeline
**Best home:** Task 9 (live instrument switching) of the instrument-profiles work, where live policy swaps are first exercised in product — or any follow-up that touches `setPolicy`.

## Problem

`PitchPipeline.setPolicy(_:)` (added in Slice 1 Task 4) is the load-bearing seam of the
instrument-profile refactor: swapping policy must **reset detection state** — it rebuilds the
`FrequencySmoother` and resets the `SustainGate`, `config`/current band, `trackedFrequency`,
`unvoicedStreak`, `prevFrame`, and `phaseIntegrator`. None of that reset behavior is exercised by
any test in the suite:

- The engine-level test (`engineStoresAndUpdatesPolicy` in `DetectionPolicyTests`) only proves the
  `TunerEngine.detectionPolicy` property round-trips. It cannot reach the pipeline (`pipeline` is
  `private`; `start()` throws `.captureUnavailable` headlessly).
- No test calls `PitchPipeline.setPolicy` directly, so the reset logic is unverified at any layer.

This did **not** affect the Slice 1 zero-delta proof (the benchmark sets policy once at init and
never swaps), which is why it was correctly deferred. It matters for **live instrument switching**
(Task 9), where a mid-stream swap must not bleed the previous instrument's tracked frequency /
lock state into the new one.

## Fix

Add a pipeline-level test that proves the **state reset**, not just propagation. A shallow test
that only asserts `policy`/`searchRange` reflect the swap is barely above the existing engine test
and is **not worth writing** — the genuinely-untested behavior is the reset.

Drive it through `PitchPipeline` directly (the harness already exists in `PipelineTests.swift`):
1. Build a pipeline (e.g. `.guitar`), `process(_:)` enough samples to build up state — reach a
   locked/stable reading on one note so `trackedFrequency`, the smoother window, the sustain
   streak, and `phaseIntegrator` are all populated.
2. `setPolicy(.bass)` (or any different policy).
3. Assert the reset took: the next readings must behave as a cold start — e.g. the smoother does
   not drag the old frequency, the sustain gate re-acquires from zero (no immediately-`stable`
   frame), and the chosen band/`searchRange` reflect the new policy. Pick assertions observable
   through `process(_:)` output (`PitchReading`), since the reset internals are private.

If the only reachable signal is too indirect, add a minimal `internal`/`@testable` accessor rather
than weakening the test to mere propagation.

## Files

- `Packages/TunerEngine/Sources/TunerEngine/Pipeline/PitchPipeline.swift` (`setPolicy`, the SUT)
- `Packages/TunerEngine/Tests/TunerEngineTests/PipelineTests.swift` (new regression test)
