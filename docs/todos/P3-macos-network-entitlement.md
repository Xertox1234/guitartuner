---
priority: P3
status: needs-spec
domain: other
source: 2026-06-14 monetization audit (PR29, finding L8)
---

# L8 — macOS App Sandbox Missing Network Client Entitlement

`LUMA.entitlements` enables the macOS app sandbox but does not include
`com.apple.security.network.client`. All monetization networking (`LumaAPI`) is currently
guarded by `#if os(iOS)`, so this is latent — macOS builds don't reach the network.

If/when the BottomDrawer (accounts, tuning cards, gear store) is brought to macOS, the
app will silently fail all network calls without this entitlement.

**File:** `App/LUMA.entitlements`

**Fix (when macOS networking is needed):**

```xml
<key>com.apple.security.network.client</key>
<true/>
```

No action required for v1 iOS-only shipping. File this as a reminder for the macOS
feature parity pass.

**Verified 2026-06-18 (P3 sweep):** still correctly deferred. `LumaAPI` networking remains
`#if os(iOS)`-guarded, so macOS builds never reach the network and the entitlement is not
needed. Deliberately NOT adding it now — `com.apple.security.network.client` would broaden
the App Sandbox for a feature that does not exist in v1, which cuts against the privacy-by-
architecture pillar. Kept open as the macOS-parity reminder; apply the entitlement only when
the BottomDrawer (accounts/cards/gear) is actually brought to macOS.
