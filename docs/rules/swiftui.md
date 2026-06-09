# SwiftUI app layer rules

- `LiveTunerModel` is `@MainActor @Observable`. All state mutations flow through it. Do not bypass it with direct engine access from views.
- Use `@Bindable` for the model in views — the model is owned by `LumaApp` and passed down. Not `@State`, not `@StateObject`.
- Persisted user preferences (strobe style, scope visibility, Metal opt-in) go in `@AppStorage`, not in `LiveTunerModel`. The model holds live, transient state.
- Stage Mode is a `ZStack` overlay — it does not restructure the base layout. Keep it isolated.
- **No networking in v1.** Do not add `URLSession`, `AsyncStream` from a URL, or any network call anywhere in the app layer. The privacy guarantee is architectural.
- Multiplatform target: iPhone/iPad/Mac (true multiplatform, not Catalyst). Use `#if os(macOS)` / `#if os(iOS)` guards where platform behavior differs.
- Menu bar tuner (`MenuBarTuner`) shares the same `LiveTunerModel` instance as the main window — it does not own its own `TunerEngine`.
- Use Swift Concurrency (`async/await`, `Task`, `actor`) everywhere. Existing code uses `AsyncStream`; match that pattern. No Combine.
- `@Observable` macro: do not add `@Published` — it's redundant and conflicts. Use `@ObservationIgnored` for properties that should not trigger view updates.
