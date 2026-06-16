import Foundation

/// JSON cache persistence for the opt-in account/store features
/// (`TuningCardStore`, `GearStoreModel`).
///
/// Centralizes the one non-obvious rule: on iOS, `Library/Application Support`
/// is **not created automatically** (it is on macOS / the Simulator). The parent
/// directory must be created before writing, or `.write(to:)` throws `ENOENT` on
/// a fresh install — the bug that crashed the app + Previews on device.
/// See docs/solutions/runtime-errors/application-support-not-created-ios-debug-assert-crash-2026-06-16.md
enum CacheFile {
    /// Atomically encodes `value` to JSON at `url`, creating intermediate
    /// directories first.
    ///
    /// A throw is the caller's signal to degrade to stale/empty data — never to
    /// crash. Callers must `catch` and log; never `assertionFailure` on this
    /// recoverable path (it traps Debug builds and no-ops Release).
    static func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
