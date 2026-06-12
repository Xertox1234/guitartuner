---
severity: medium
audit: 2026-06-12-full
finding: M4
---

# M4 — `LumaPalette` AppStorage Round-Trip Untested

`StrobeStyle` has a `testRawValueRoundTripForAppStorage` test; `LumaPalette` does not.
A case rename would silently fall back to `.aurora` for existing users with no compile error.

**File:** `LumaDesignSystem/Tests/LumaDesignSystemTests/LumaPaletteTests.swift`

**Fix:** Add:
```swift
@Test func rawValueRoundTripForAppStorage() {
    for palette in LumaPalette.allCases {
        #expect(LumaPalette(rawValue: palette.rawValue) == palette)
    }
    #expect(LumaPalette(rawValue: "nonexistent") == nil)
}
```

**Tests:** `swift test --package-path Packages/LumaDesignSystem`
