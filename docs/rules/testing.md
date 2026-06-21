# Testing rules

- Use **Swift Testing** framework (`@Test`, `@Suite`, `#expect`, `#require`) for all new tests. Not XCTest (legacy).
- Test `PitchPipeline` headlessly — push synthesized samples directly; no `AVAudioEngine`, no audio device, no CI dependency on hardware.
- Use `TunerEngine/Bench/Stimulus.swift` to generate synthesized test tones at known frequencies. Use `Fixtures.swift` for file-based regression inputs at known cents.
- The **accuracy benchmark is CI-blocking**. Do not merge changes that degrade `docs/benchmarks/accuracy.md` beyond the gates in `BenchmarkSuite.swift`. A change that improves one frequency band but regresses another requires explicit sign-off.
- The published spec `accuracy.md` **is the Linux CI artifact** (the `--ci` gate runs on `ubuntu-latest`, not macOS); `accuracy.csv` is **gitignored** (per-run, not committed). Re-baseline by pulling the `accuracy-report` artifact (`gh run download -n accuracy-report`), never by committing a local macOS regen (vDSP vs scalar differs in deep decimals). **Stress-family `max`/`σ` (vibrato/decay-glide/weak-fund) are toolchain-chaotic pre-lock acquisition transients, not a floor** — gate only octave-safety (`stressOctaveErrors == 0`) + post-1 s lock-σ, never stress max/abs. See `docs/solutions/best-practices/accuracy-spec-is-linux-artifact-stress-metrics-toolchain-chaotic-2026-06-20.md`.
- Tests live in the package's `Tests/` directory, co-located with the module they test.
- Tests must be **deterministic** — no audio hardware dependency, no timing sensitivity, no network. All DSP tests run with synthesized/file input.
- When testing strobe behavior: use `StrobeInput` directly with known `phase` values — do not spin up the full engine just to test rendering.
- `LumaDesignSystemTests` tests model logic (`LumaMusic`, `TunerVisualState`, `StrobeMath`) — keep UI rendering untested (use Previews for visual verification instead).
