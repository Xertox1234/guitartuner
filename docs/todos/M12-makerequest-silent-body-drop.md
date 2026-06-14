---
severity: medium
audit: 2026-06-14-monetization-pr29
finding: M12
---

# M12 — makeRequest Silently Drops Request Body on Encoder Failure

`LumaAPI.makeRequest` encodes the body with `try?`, silently sending a bodyless POST
if encoding ever fails:

```swift
req.httpBody = try? JSONEncoder().encode(body)
```

`JSONEncoder` cannot fail on these simple `Codable` structs today, but a future type
with a custom `encode(to:)` implementation could break silently — the server would
receive an empty body and return a confusing 400 or 422 error.

**File:** `App/Networking/LumaAPI.swift` — `makeRequest` method

**Fix:** Use `try!` with a comment (encode failure here is a programmer error, not a
runtime condition), or convert `makeRequest` to a throwing function:

```swift
// Option A — assert (encode failure = programmer error, not user error)
req.httpBody = try! JSONEncoder().encode(body)

// Option B — throw (more correct but requires caller changes)
req.httpBody = try JSONEncoder().encode(body)
// and mark makeRequest as throws
```

Option A is appropriate here since all request body types are simple value types with
derived `Codable` conformance.
