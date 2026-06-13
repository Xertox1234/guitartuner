---
title: "macOS sandboxed/hardened-runtime build needs com.apple.security.device.audio-input or AVAudioEngine.start() silently fails"
track: knowledge
category: conventions
tags: [capture, pipeline]
module: TunerEngine
applies_to:
  - "App/LUMA.entitlements"
  - "project.yml"
  - "Packages/TunerEngine/Sources/TunerEngine/Capture/MicrophonePermission.swift"
created: 2026-06-12
---

## When this applies

Any macOS build that runs with App Sandbox enabled (`com.apple.security.app-sandbox`) OR
with the Hardened Runtime required for notarization — i.e. every Mac App Store build and every
Developer-ID notarized build.

## The pattern

`App/LUMA.entitlements` must contain both keys:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
```

Wire it in `project.yml` via `CODE_SIGN_ENTITLEMENTS: App/LUMA.entitlements` and exclude the
file from the source glob so XcodeGen doesn't compile it:

```yaml
sources:
  - path: App
    excludes:
      - "LUMA.entitlements"
```

## Why

Without `com.apple.security.device.audio-input`, the OS TCC layer still reports
`AVCaptureDevice.authorizationStatus(for: .audio) == .authorized` — so the permission check in
`MicrophonePermission.swift` passes — but `AVAudioEngine.start()` fails at the kernel level.
The error surfaces as `TunerEngineError.engineStartFailed`, **not** `microphonePermissionDenied`.

This is the non-obvious failure mode: the app thinks it has permission (status says so), starts
the engine, and blows up one step later with an opaque audio engine error. Without knowing this
constraint, the root cause looks like an engine bug, not a missing entitlement.

Both keys are required together: `com.apple.security.device.audio-input` has no effect without
`com.apple.security.app-sandbox` on a hardened-runtime build.

iOS does not use entitlements for mic access — `NSMicrophoneUsageDescription` in Info.plist plus
the runtime prompt is sufficient; these keys are silently ignored on iOS.

## Related files

- `App/LUMA.entitlements` — the entitlements plist
- `project.yml` — wires `CODE_SIGN_ENTITLEMENTS`; excludes the file from the source glob
- `Packages/TunerEngine/Sources/TunerEngine/Capture/MicrophonePermission.swift` — the permission
  check that passes even when the entitlement is missing
