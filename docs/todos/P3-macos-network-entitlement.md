---
priority: P3
status: needs-spec
domain: other
source: 2026-06-14 monetization audit (PR29, finding L8)
---

# L8 — macOS App Sandbox Missing Network Client Entitlement

`LUMA.entitlements` enables the macOS app sandbox but does not include
`com.apple.security.network.client`. This is latent — macOS builds never *trigger* a
network call, so the missing entitlement has no effect today.

Note the guarantee is **call-site / view-tree gating, not module gating**: `App/Networking/`
has zero `#if os(...)` guards, and `LumaApp.init` constructs `LumaAPI` + all three models
(`AccountModel`, `TuningCardStore`, `GearStoreModel`) on every platform. Construction fires
no request — the models' `init`s only read Keychain/local cache and `URLSession` is lazy.
Every method that actually hits the network (`fetch`, `login`/`register`/`signInWithApple`,
`save`/`delete`, `subscribeMarketing`) is reachable only through the `BottomDrawer` subtree
(`AccountSheet`, `SaveCardSheet`, `GearStoreScreen`), and `BottomDrawer.swift` is wholly
`#if os(iOS)`. `AccountModel.api` is a public `let`, but no view does a direct `.api.` call,
so nothing bypasses that gating. `MenuBarTuner` (the macOS surface) touches no monetization
model.

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

**Verified 2026-06-21 (review):** still correctly deferred — but the prior note's mechanism
was wrong and has been rewritten above. `LumaAPI` is **not** `#if os(iOS)`-guarded (and is
constructed on macOS); the real guarantee is that every network *trigger* is reachable only
from the iOS-gated `BottomDrawer` subtree. Confirmed by code read: no direct `.api.` access
from any view (`grep -rn '\.api\.' App` is empty), all `api.get/post/delete` calls live inside
the three model files and are invoked only from the drawer subtree, and `MenuBarTuner` uses no
monetization model. macOS CI build gate is green post-#57, corroborating the gating compiles.
Deliberately NOT adding the entitlement now — `com.apple.security.network.client` would
broaden the App Sandbox for a feature that does not exist in v1, against the privacy-by-
architecture pillar. (Sign in with Apple needs no `network.client`: the credential flow is
out-of-process; only the follow-up `api.post("auth/apple")` hits the network, and that is
iOS-gated.) Apply the entitlement only when the BottomDrawer is actually brought to macOS.

> ~~**Verified 2026-06-18 (P3 sweep):** `LumaAPI` networking remains `#if os(iOS)`-guarded…~~
> Superseded — that claim was factually incorrect (`App/Networking/` has no OS guards).
