---
title: "iOS-only #if os(iOS) code is type-checked in CI only by the iOS-Simulator build — beware SDK skew"
track: knowledge
category: best-practices
tags: [capture, swiftui]
module: App
applies_to: ["Packages/TunerEngine/Sources/TunerEngine/Capture/AudioCapture.swift", "App/Engine/ToneGenerator.swift", ".github/workflows/ci.yml"]
created: 2026-06-16
---

## When this applies

Any time you edit `#if os(iOS)` code that touches an iOS-only framework (AVAudioSession,
UIKit, …), reference a recent-SDK symbol, or change CI's runner / Xcode. The trap bites
hardest when your **local Xcode is newer than CI's** (e.g. local 26.5 vs CI 16.2).

## The pattern

1. **In CI, `#if os(iOS)` code is compiled by exactly one job step: the
   `generic/platform=iOS Simulator` `xcodebuild` build.** The Linux `swift test`
   (engine) and the `platform=macOS` build/test **never** type-check it. So a symbol
   error inside `#if os(iOS)` is invisible to every gate except that one step — and a
   *clean* iOS build at that (local incremental builds cache the stale `.o` and hide it).

2. **Never reference a symbol newer than CI's build SDK.** `#available` / `if #available`
   gates **runtime OS availability** of an API that already exists in the SDK you compile
   against. It does **nothing** for compile-time symbol resolution — referencing a symbol
   absent from the build SDK fails type-checking before any availability logic runs. To
   use a newer-only symbol from older-SDK builds you need conditional *compilation*
   (`#if compiler(...)` / `#if canImport`), not `#available`. In practice: **use the name
   that exists in the lowest SDK you build against.**

3. **Prefer a pinned Xcode + a required status check over chasing `latest-stable`.**
   `xcode-version: latest-stable` is a *floating* target — the runner image moves under
   you, so a green `main` can go red with zero code change (non-reproducible CI). Pinning
   an explicit `xcode-version: 'NN.N'` and bumping it deliberately via PR is reproducible
   and still catches "you used a symbol newer than our floor." And make the iOS-Simulator
   build a **required status check** on `main` — as of this writing `main` has *no* branch
   protection, which is how the broken commit reached it while CI was red.

4. **Debugging CI compile failures: use `gh run view <id> --log`, not `--log-failed`.**
   `--log-failed` truncated the real `error:` line here and the failure *presented as a
   compiler OOM* ("Command SwiftCompile failed with a nonzero exit code", no diagnostic,
   on a large batch). That red herring cost ~an hour. The full `--log` showed the actual
   `has no member 'allowBluetoothHFP'` immediately.

## Why

This is the concrete incident that taught it: `AudioCapture.swift` and `ToneGenerator.swift`
configured their `AVAudioSession` with `.allowBluetoothHFP`. That option exists **only in
the iOS 26 SDK (Xcode 26)** — it is the iOS-26 *rename* of `.allowBluetooth` (same
underlying `AVAudioSessionCategoryOptionAllowBluetooth` bit, `0x4`; behaviour-identical;
the rename only disambiguates HFP from A2DP). It compiled on the developer's local
**Xcode 26.5** but not on CI's **Xcode 16.2** (the `macos-14` runner's `latest-stable`,
iOS 18.2 SDK), where the symbol does not exist. Because the session code is `#if os(iOS)`,
no other CI lane compiled it, so it red-lit the iOS-Simulator build on `main` and every PR.

Fix that landed: `.allowBluetoothHFP` → `.allowBluetooth` in both files (the spelling that
exists in every SDK we build against; not deprecated on the iOS 17 SDK, deprecation warning
only on Xcode 26), and the runner bumped `macos-14` → `macos-15` so `latest-stable` resolves
to Xcode 26.3, near the local toolchain.

**The runner bump narrows the skew window; it does not close it.** The structural guarantee
is point 1 — the iOS-Simulator lane type-checks `#if os(iOS)` code — reinforced by points 3
(pin + required check). `latest-stable` will always lag a brand-new local Xcode.

## Examples

```swift
// ❌ iOS-26-only symbol — compiles on local Xcode 26, hard error on CI Xcode 16.2,
//    and invisible to `swift test` / the macOS build because it's inside #if os(iOS).
try session.setCategory(.playAndRecord, mode: .measurement,
                        options: [.allowBluetoothHFP, .defaultToSpeaker])

// ✅ Same bit, exists in every SDK we build against; correct for the iOS 17 target.
try session.setCategory(.playAndRecord, mode: .measurement,
                        options: [.allowBluetooth, .defaultToSpeaker])
```

## Follow-ups worth a ticket (not part of the fix)

- **Pin CI's Xcode** (`xcode-version: 'NN.N'`) and add the iOS-Simulator build as a
  required status check on `main` (currently unprotected).
- **Is Bluetooth HFP even right here?** HFP input is 8–16 kHz, lossy, AGC-prone — at odds
  with a `.measurement`-mode strobe-grade tuner. Worth questioning whether `.allowBluetooth*`
  belongs on the *record* session at all (its value here is mostly the playback/tone path).
  Pre-existing design choice, untouched by this fix.

## Related files

- `Packages/TunerEngine/Sources/TunerEngine/Capture/AudioCapture.swift` (line 107 — capture session)
- `App/Engine/ToneGenerator.swift` (line 102 — tone playback session)
- `.github/workflows/ci.yml` (the iOS-Simulator build step; runner = `macos-15`)
