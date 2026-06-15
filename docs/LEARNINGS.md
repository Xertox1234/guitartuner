# LUMA — Learnings

Non-obvious discoveries from development, newest first. Detailed write-ups live in `docs/solutions/`.

<!-- Format: - YYYY-MM-DD: [one-liner] → [link to solution file if written] -->
- 2026-06-14: PhaseIntegrator must always use maxPartials=1, B=0 — multi-partial Fisher fusion is unsafe in the pipeline because B estimation fails for very low bass pure tones → [solutions/phase-integrator-n1-only-design-2026-06-14.md](solutions/phase-integrator-n1-only-design-2026-06-14.md)
- 2026-06-14: HarmonicEstimator's `minBin=6` causes sidelobe-as-fake-partial contamination on noiseless B0 pure tones, producing +11¢ f0 bias in the pre-convergence window (bogus B is negative and safely discarded; integrator self-corrects) → [solutions/harmonic-estimator-virtual-candan-failure.md](solutions/harmonic-estimator-virtual-candan-failure.md)
- 2026-06-12: macOS sandboxed/hardened-runtime builds silently fail at `AVAudioEngine.start()` (not at the permission check) when `com.apple.security.device.audio-input` entitlement is missing → [solutions/macos-audio-input-entitlement-2026-06-12.md](solutions/macos-audio-input-entitlement-2026-06-12.md)
- 2026-06-12: macOS Settings deep link for mic privacy is an undocumented compat shim — works via `openURL`/`NSWorkspace` but has no Apple stability guarantee; verify on each major OS release → [solutions/mic-permission-denied-settings-deeplink-2026-06-12.md](solutions/mic-permission-denied-settings-deeplink-2026-06-12.md)
