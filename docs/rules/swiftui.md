# SwiftUI app layer rules

- `LiveTunerModel` is `@MainActor @Observable`. All state mutations flow through it. Do not bypass it with direct engine access from views.
- Use `@Bindable` for the model in views — the model is owned by `LumaApp` and passed down. Not `@State`, not `@StateObject`.
- Persisted user preferences (strobe style, scope visibility, Metal opt-in) go in `@AppStorage`, not in `LiveTunerModel`. The model holds live, transient state.
- Stage Mode is a `ZStack` overlay — it does not restructure the base layout. Keep it isolated.
- **Networking & audio privacy:** all backend calls go through `LumaAPI`; audio never leaves the device. Canonical: `docs/rules/security.md`.
- Multiplatform target: iPhone/iPad/Mac (true multiplatform, not Catalyst). Use `#if os(macOS)` / `#if os(iOS)` guards where platform behavior differs.
- **`#if os(iOS)` code is type-checked in CI only by the `iOS Simulator` build step** — not `swift test`, not the macOS build. So an iOS-only symbol newer than CI's Xcode SDK (e.g. an iOS-26-only API used while CI is on Xcode 16.2) compiles on your local Xcode but breaks CI, and only there. Use the spelling in the lowest SDK you build against; `#available` gates runtime, not symbol existence. See `docs/solutions/best-practices/ios-only-code-ci-sdk-skew-2026-06-16.md`.
- Menu bar tuner (`MenuBarTuner`) shares the same `LiveTunerModel` instance as the main window — it does not own its own `TunerEngine`.
- Use Swift Concurrency (`async/await`, `Task`, `actor`) everywhere. Existing code uses `AsyncStream`; match that pattern. No Combine.
- `@Observable` macro: do not add `@Published` — it's redundant and conflicts. Use `@ObservationIgnored` for properties that should not trigger view updates.
- **URL/route construction:** use `LumaAPI.buildURL` / `appending(path:)`, never `appending(component:)` for routes. Canonical: `docs/rules/security.md`.
- **Never `assertionFailure`/`fatalError`/`precondition` on a recoverable path** (cache write, network response, external-data decode). They crash Debug builds (SIGTRAP / "signal 5" — Xcode Run, Previews, on-device debug) and are no-ops in Release, so you get dev-time crashes *and* silent prod failures. Log with `os.Logger` (never `print`) and degrade to stale/empty data. Canonical: `docs/rules/security.md`. See `docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md`.
- **`Application Support` is not auto-created on iOS** (it is on macOS / the Simulator). Before writing a cache there, `FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)`, or resolve with `url(for:in:appropriateFor:create: true)` — a missing dir makes `.write(to:)` throw `ENOENT` on a fresh install.
