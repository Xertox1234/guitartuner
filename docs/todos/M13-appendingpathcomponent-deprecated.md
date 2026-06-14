---
severity: medium
audit: 2026-06-14-monetization-pr29
finding: M13
---

# M13 — appendingPathComponent Deprecated in iOS 16+

`TuningCardStore` and `GearStoreModel` both call `URL.appendingPathComponent(_:)` which
was deprecated in iOS 16 / macOS 13 in favour of `URL.appending(component:)`.

**Files:**
- `App/Tunings/TuningCardStore.swift` — `cacheURL` computed property
- `App/Store/GearStoreModel.swift` — `cacheURL` computed property

**Fix:**

```swift
// Before
let cacheURL = baseURL.appendingPathComponent("luma_tuning_cards.json")

// After (iOS 16+ / macOS 13+)
let cacheURL = baseURL.appending(component: "luma_tuning_cards.json")
```

LUMA targets iOS 17+ and macOS 14+, so the new API is always available. No availability
guard needed.
