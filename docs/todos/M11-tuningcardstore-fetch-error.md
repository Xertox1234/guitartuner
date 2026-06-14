---
severity: medium
audit: 2026-06-14-monetization-pr29
finding: M11
---

# M11 — TuningCardStore.fetch Sets Error Even When Stale Cache Exists

`TuningCardStore.fetch` sets `self.error` on any network failure, even when `cards`
already has a valid cached result. This shows an error banner to users who have perfectly
usable cached tuning cards. `GearStoreModel.fetch` correctly handles this — it stays
silent when `products` is non-empty.

**File:** `App/Tunings/TuningCardStore.swift` — catch block in `fetch()`

**Fix:** Mirror `GearStoreModel`'s pattern:

```swift
} catch {
    if cards.isEmpty {
        self.error = error.localizedDescription
    }
    // else: stale cache is serviceable; stay silent
}
```

**Test:** Verify by loading cards once (populates cache), then fetching again while offline —
no error string should appear, and the cached cards should remain visible.
