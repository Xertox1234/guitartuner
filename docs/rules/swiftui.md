# SwiftUI app layer rules

- `LiveTunerModel` is `@MainActor @Observable`. All state mutations flow through it. Do not bypass it with direct engine access from views.
- Use `@Bindable` for the model in views — the model is owned by `LumaApp` and passed down. Not `@State`, not `@StateObject`.
- Persisted user preferences (strobe style, scope visibility, Metal opt-in) go in `@AppStorage`, not in `LiveTunerModel`. The model holds live, transient state.
- Stage Mode is a `ZStack` overlay — it does not restructure the base layout. Keep it isolated.
- **Audio never leaves the device.** `TunerEngine` has no networking; the privacy guarantee is architectural. The opt-in account/monetization stack (`LumaAPI`, `AccountModel`, `TuningCardStore`, `GearStoreModel`) uses `URLSession` for backend calls with explicit user consent — this is intentional. Do not add networking outside of `LumaAPI`.
- Multiplatform target: iPhone/iPad/Mac (true multiplatform, not Catalyst). Use `#if os(macOS)` / `#if os(iOS)` guards where platform behavior differs.
- Menu bar tuner (`MenuBarTuner`) shares the same `LiveTunerModel` instance as the main window — it does not own its own `TunerEngine`.
- Use Swift Concurrency (`async/await`, `Task`, `actor`) everywhere. Existing code uses `AsyncStream`; match that pattern. No Combine.
- `@Observable` macro: do not add `@Published` — it's redundant and conflicts. Use `@ObservationIgnored` for properties that should not trigger view updates.
- URL construction in `LumaAPI`: always use `LumaAPI.buildURL(base:path:)` — never `URL.appending(component:)` directly. `appending(component:)` percent-encodes slashes, silently turning `"auth/apple"` into `auth%2Fapple` and breaking routing. `appending(path:)` (wrapped by `buildURL`) treats slashes as separators.
