---
severity: low
audit: 2026-06-14-monetization-pr29
finding: L8
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
