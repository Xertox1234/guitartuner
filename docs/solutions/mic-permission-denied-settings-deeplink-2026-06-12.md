---
title: "Mic-denied UX: platform-fenced Settings deep link + permissionDenied flag must clear on successful start only"
track: knowledge
category: best-practices
tags: [swiftui]
module: App
applies_to:
  - "App/LiveTunerScreen.swift"
  - "App/Engine/LiveTunerModel.swift"
created: 2026-06-12
---

## When this applies

Any SwiftUI view that recovers from `TunerEngineError.microphonePermissionDenied` by offering
the user a link to re-grant mic access in system settings.

## The pattern

**Model side (`LiveTunerModel`):** expose a `private(set) var permissionDenied = false` flag.
Set it only in the `catch` block where `.microphonePermissionDenied` is detected; clear it on
every successful `start()`. Do **not** clear it in `stop()` — `stop()` carries no evidence
about permission state and clearing there hides an unresolved denial.

```swift
// on successful start:
permissionDenied = false

// in the catch block:
permissionDenied = (error as? TunerEngineError) == .microphonePermissionDenied
```

**View side (`LiveTunerScreen`):** show the button only when both the flag is set AND the URL
resolves. The optional bind is the correct guard — on a platform where `microphoneSettingsURL`
returns `nil` the button is fully suppressed.

```swift
if model.permissionDenied, let url = microphoneSettingsURL {
    Button("Open Settings") { openURL(url) }
}
```

**URL computation (platform-fenced):**

```swift
private var microphoneSettingsURL: URL? {
    #if os(iOS)
    URL(string: UIApplication.openSettingsURLString)   // documented Apple API
    #elseif os(macOS)
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    #else
    nil
    #endif
}
```

## Why

The iOS URL (`UIApplication.openSettingsURLString`) is documented Apple API and stable.

The macOS URL is **not a documented API** — it is a Monterey-era preference pane anchor carried
forward via a compatibility shim after the System Preferences → System Settings rename. It works
correctly when dispatched through `@Environment(\.openURL)` (which routes via
`NSWorkspace.shared.open()` on macOS), but Apple provides no stability guarantee for the
`com.apple.preference.security?Privacy_Microphone` anchor. **Verify it still lands on the right
pane after each major macOS release** — if it breaks, the failure mode is a silent no-op (the
button does nothing), not a crash.

Using the optional bind (`if let url`) rather than just `if permissionDenied` ensures the button
is never rendered on a platform that returns `nil` (the `#else` branch), preventing a dead UI
element.

## Related files

- `App/Engine/LiveTunerModel.swift` — `permissionDenied` flag, set/clear logic
- `App/LiveTunerScreen.swift` — `microphoneSettingsURL`, button display
