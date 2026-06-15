---
title: "Use appending(path:) not appending(component:) for multi-segment API paths"
track: bug
category: logic-errors
tags: [swiftui]
module: App
applies_to: ["App/Networking/LumaAPI.swift"]
created: 2026-06-15
---

## Symptom

Sign in with Apple (and all other API calls) returned `URLError.unknown (-1)` on device. Face ID completed successfully, the AccountSheet dismissed without showing an error, but the user was never actually signed in. Backend logs showed no request arriving at the correct route.

## Root cause

`URL.appending(component:)` (iOS 16+) treats its entire argument as a single opaque path component and **percent-encodes any forward slashes**. Passing `"auth/apple"` produces `.../auth%2Fapple`. Cloudflare's router has no route matching that literal string and returns `404 text/plain`. URLSession surfaces this as `URLError.unknown (-1)` rather than an HTTP error, so the error message shown to the user was "unknown error" with no actionable detail.

A voluntary modernization pass replaced `appendingPathComponent("auth/apple")` with `appending(component: "auth/apple")`. The two methods look like synonyms but are not:

| Method | Slash handling | Result for `"auth/apple"` |
|--------|---------------|--------------------------|
| `appendingPathComponent(_:)` | slash = separator | `.../auth/apple` ✓ |
| `appending(path:)` | slash = separator | `.../auth/apple` ✓ |
| `appending(component:)` | slash = encoded | `.../auth%2Fapple` ✗ |

Note: `appendingPathComponent` is discouraged by style but carries no compiler deprecation warning. The migration to `appending(component:)` was incorrect.

## Fix

All URL construction in `LumaAPI` now goes through `LumaAPI.buildURL(base:path:)`, a static internal helper that enforces `appending(path:)`:

```swift
static func buildURL(base: URL, path: String) -> URL {
    base.appending(path: path)
}
```

Call sites in `makeRequest` and `refreshToken` both use this helper. The helper is unit-tested in `LUMATests/LumaAPIURLTests.swift` with an explicit `%2F` assertion so a future swap back to `component:` breaks CI immediately.

## Why it was wrong

`appending(component:)` is the correct choice only when the argument is literally one path segment with no separators (e.g. a UUID or filename). For any path string that contains or may contain slashes, use `appending(path:)`.

## Related files

- `App/Networking/LumaAPI.swift` — all URL construction
- `LUMA/Tests/LumaAPIURLTests.swift` — regression tests
