# Testing rules

- Use **Swift Testing** framework (`@Test`, `@Suite`, `#expect`, `#require`) for all new tests. Not XCTest (legacy).
- Test `PitchPipeline` headlessly — push synthesized samples directly; no `AVAudioEngine`, no audio device, no CI dependency on hardware.
- Use `TunerEngine/Bench/Stimulus.swift` to generate synthesized test tones at known frequencies. Use `Fixtures.swift` for file-based regression inputs at known cents.
- The **accuracy benchmark is CI-blocking**. Do not merge changes that degrade `docs/benchmarks/accuracy.md` beyond the gates in `BenchmarkSuite.swift`. A change that improves one frequency band but regresses another requires explicit sign-off.
- Tests live in the package's `Tests/` directory, co-located with the module they test.
- Tests must be **deterministic** — no audio hardware dependency, no timing sensitivity, no network. All DSP tests run with synthesized/file input.
- When testing strobe behavior: use `StrobeInput` directly with known `phase` values — do not spin up the full engine just to test rendering.
- `LumaDesignSystemTests` tests model logic (`LumaMusic`, `TunerVisualState`, `StrobeMath`) — keep UI rendering untested (use Previews for visual verification instead).
