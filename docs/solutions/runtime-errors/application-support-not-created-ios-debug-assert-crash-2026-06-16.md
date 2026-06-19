---
title: "Never assertionFailure/fatalError in a catch labeled 'non-fatal'; create Application Support before cache writes on iOS"
track: bug
category: runtime-errors
tags: [swiftui, security]
module: App
applies_to: ["App/Persistence/CacheFile.swift", "App/Tunings/TuningCardStore.swift", "App/Store/GearStoreModel.swift", "App/Tunings/TuningCard.swift"]
created: 2026-06-16
---

## Symptom

LUMA crashed **immediately on launch** on a physical iPhone 16 Pro Max — both the
installed app and SwiftUI Previews — but ran fine on the iOS Simulator and on
macOS. Deleting the app from the phone made it crash **every** time.

Device-captured crash (via `xcrun devicectl … process launch --console`):

```
LUMA/TuningCardStore.swift:72: Fatal error: TuningCardStore: cache write failed —
  Error Domain=NSCocoaErrorDomain Code=4 "The folder "luma_tuning_cards.json" doesn't exist."
  … NSUnderlyingError POSIX Code=2 "No such file or directory"
  … NSURL=…/Library/Application Support/luma_tuning_cards.json
App terminated due to signal 5.
```

## Root cause

`TuningCardStore` and `GearStoreModel` persisted a JSON cache to
`Library/Application Support/…` and wrote with `.write(to:, options: .atomic)`.

**On iOS, `Application Support` is not created automatically** (on macOS the
user-level `~/Library/Application Support` already exists; the Simulator's
container happened to have it present). On a fresh device install the parent
directory is missing, so `.write(to:)` throws `NSCocoaError 4` (POSIX `ENOENT`).

The real trap, though, is the `catch`: it called **`assertionFailure(...)`** on a
path the author's own comment labeled *"Non-fatal."* That is the headline lesson —
a **debug-fatal assert in a "non-fatal" catch block**:

1. `assertionFailure` / `precondition` / `fatalError` **trap in Debug builds**
   (SIGTRAP → "signal 5"). Xcode Run, Previews, and on-device debug builds are all
   Debug, so they crashed.
2. In **Release** `assertionFailure` compiles to a **no-op** — so this never
   crashed in production, but the cache **silently failed to persist on every
   launch** (the directory never existed). The bug was latent in Release the whole
   time; caching simply never worked.
3. The **platform split actively misdirects diagnosis**: Simulator + macOS pass,
   device + Previews crash. It reads like a device/preview-environment problem, not
   a filesystem one.

Note it crashed on **write only**: `loadCache()` reads with `try? Data(contentsOf:)`,
which returns `nil → []` when the file/dir is missing — so `init` (which only
reads) did not blow up first. The crash needed `fetch()` to succeed and reach
`persistCache()`.

## Fix

In each store's `persistCache()`, create the directory before writing, and
downgrade the assert to a non-fatal log (matching the codebase: `print("[LUMA] …")`
is the established convention — there is no `os.Logger` in `App/`):

```swift
private func persistCache() {
    do {
        // Application Support is not created automatically on iOS — ensure the
        // parent directory exists, or .write(to:) fails with ENOENT on first run.
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(cards).write(to: cacheURL, options: .atomic)
    } catch {
        // Non-fatal: stale cache on next launch; no user-visible failure.
        print("[LUMA] TuningCardStore: cache write failed — \(error)")
    }
}
```

Per-write `createDirectory(withIntermediateDirectories: true)` is the right
placement (not init-time): it is idempotent (does not throw if the dir exists) and
survives a directory deleted mid-session. The canonical one-shot idiom for future
writers is `FileManager.default.url(for: .applicationSupportDirectory, in:
.userDomainMask, appropriateFor: nil, create: true)`, which creates the directory
at URL-resolution time.

The create-dir-then-write logic is now centralized in `CacheFile.write(_:to:)`
(`App/Persistence/CacheFile.swift`); both stores delegate to it, so a future cache
writer cannot silently reintroduce the missing-directory bug.

A third instance of the same anti-pattern, `TuningCard.strings`, sat on the exact
`fetch()` decode path and was downgraded the same way (corrupt `strings_json` →
empty tuning + log, instead of a Debug crash).

## Why it was wrong

A cache write / data decode is a **recoverable** path — stale or empty data is the
correct fallback, never a crash. `assertionFailure` in those catch blocks
contradicts the "non-fatal" intent: it crashes Debug and no-ops Release, giving you
the worst of both (dev-time crashes + silent prod failure). Rule of thumb for this
codebase: **never `assertionFailure`/`fatalError`/`precondition` on a cache,
network-response, or external-data path — log with `print("[LUMA] …")` and degrade.**

## Verification

- Reproduced on the iPhone 16 Pro Max via `devicectl` (died in ~1 s with the fatal
  error above).
- Built a signed Debug build with the fix, installed + launched via the same
  `devicectl` harness → app runs **past** the previous crash point (process stays
  alive). Preview independently confirmed working on device.
- Automated regression: `LUMA/Tests/CacheFileTests.swift` writes to a not-yet-
  existing nested directory and asserts the file is created. Confirmed it goes red
  with `NSCocoaError 4` / `ENOENT` — the exact device signature — when the
  `createDirectory` line is removed. CI now runs the macOS `LUMATests` bundle via
  `xcodebuild test` (the macOS job previously only `build`-ed the app, so these
  app-layer tests had never executed), so the guard runs on every push.

## Related / follow-up

- Both stores previously resolved the cache dir with `FileManager.default.urls(for:
  .applicationSupportDirectory, in: .userDomainMask)[0]` — a force subscript that
  would be **Release-fatal** if the array were ever empty (violates the repo's
  no-force-unwrap rule). Now resolved via the modern non-optional
  `URL.applicationSupportDirectory` (iOS 16+/macOS 13+; deployment targets are iOS
  17 / macOS 14). Prefer that over the `urls(...)[0]` form for known system
  directories.

## Related files

- `App/Persistence/CacheFile.swift` (shared create-dir-then-write helper)
- `App/Tunings/TuningCardStore.swift` (`persistCache` → `CacheFile.write`)
- `App/Store/GearStoreModel.swift` (`persistCache` → `CacheFile.write`)
- `App/Tunings/TuningCard.swift` (`strings` decode path)
- `App/LumaApp.swift` (single-owner `@State` instantiation — why per-write is cheap)
- `LUMA/Tests/CacheFileTests.swift` (regression guard)
- `.github/workflows/ci.yml` (macOS job now runs `LUMATests` via `xcodebuild test`)
