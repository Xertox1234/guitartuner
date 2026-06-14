---
severity: medium
audit: 2026-06-14-monetization-pr29
finding: M10
---

# M10 — JWT Keychain Item Inaccessible After Reboot Until First Unlock

`KeychainStore.write` does not set `kSecAttrAccessible`, so items use the default
`kSecAttrAccessibleWhenUnlocked`. On a locked device (e.g. background push triggers a
JWT refresh), `read` returns `nil` because the item isn't accessible until the user unlocks.

**File:** `App/Account/KeychainStore.swift` — `write(key:value:)` method

**Fix:** Add `kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock` to both the delete
and add queries in `write`:

```swift
let addQuery: [String: Any] = [
    kSecClass as String:            kSecClassGenericPassword,
    kSecAttrService as String:      service,
    kSecAttrAccount as String:      key,
    kSecValueData as String:        data,
    kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,  // add this
]
```

`kSecAttrAccessibleAfterFirstUnlock` allows background access once the device has been
unlocked at least once since boot — appropriate for auth tokens.

**Note:** `kSecAttrAccessible` applies at write time; existing items will keep their old
accessibility class until the next write. A migration is not required since token refresh
will naturally re-write the item on next login.
