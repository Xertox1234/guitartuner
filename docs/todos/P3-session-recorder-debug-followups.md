---
priority: P3
status: open
domain: swiftui
source: 2026-06-22 session-recorder final whole-branch review (feat/session-recorder)
---

# Session-recorder (DEBUG-only) follow-ups deferred at merge

Three Minor items from the final review of the DEBUG-only real-instrument session
recorder. All are **DEBUG-only** (compiled out of release) and were consciously
deferred — the feature merged with the user's explicit "accept + follow-up" call.
None affect release behavior, CI, the accuracy benchmark, or the live tuning path.

## Problem

**1. Encode + write runs on the `@MainActor` (deviates from spec §4).**
`LiveTunerModel.stopRecording` (`@MainActor`) calls `SessionRecorder.write` (`@MainActor`),
which builds the WAV `Data` byte-by-byte (`Fixtures.encodeWAVFloat32`) and does a synchronous
`Data.write(to:)` — all on the main actor. Spec §4 (design doc, line 90) says: *"On stop,
encode Float32 WAV + CSV **off the main actor**, return file URLs."* Impact: imperceptible for
realistic short takes (~10–70 ms), but a ~few-hundred-ms UI hang for a 5-min capped take
(~57 MB). The plan dropped the off-main-actor requirement; the implementation faithfully
followed the plan.

**2. `rawSamples` continuation clear is not generation-aware.**
`TunerEngine.clearRawContinuation()` nils the single `rawContinuation` slot unconditionally,
so a *previous* stream's late `onTermination` (firing after a new `rawSamples` was minted)
could clear the *new* continuation. The multi-consumer `readings` stream avoids this with a
UUID-keyed dict. Unreachable programmatically today (single consumer; the Record button is
`.disabled(!model.running)` and gated behind sheets, so start/stop is human-paced while the
stale-clear `Task` drains in microseconds) — but it's an asymmetry worth closing.

**3. A take is discarded if naming fails on the auto/chromatic path.**
`stopRecording`'s `defer { recorder = nil }` runs on the naming-failure return path too. In
auto/chromatic mode (no target), tapping the LabelSheet "Save" with an empty or invalid label
→ `fixtureStem` returns nil → `stopRecording` returns nil with the recorder already nil'd → the
in-memory take is discarded (not written). The documented capture workflow uses lock mode
(always nameable) and never hits this; recoverable by re-recording.

## Fix

**1.** Snapshot `samples`/`readings`/metadata into a `Sendable` payload on the main actor (cheap;
COW, and the recorder is discarded right after), make `stopRecording` `async`, and run the
encode + file write in `await Task.detached { try payload.write(...) }.value`. The UI call site
becomes `Task { let urls = await model.stopRecording(...); ... }` with a brief "saving…" state.

**2.** Mirror `readings`: capture a generation token (or UUID) in the `rawSamples`
`onTermination` closure and only clear `rawContinuation` if it is still that generation.

**3.** Don't nil `recorder` on the naming-failure return (so the user can retry naming), and
disable the LabelSheet "Save" button when `stem == nil && label.isEmpty`.

## Files

- `App/Engine/LiveTunerModel.swift` (`stopRecording`, `currentMetadata` — items 1 & 3)
- `App/Engine/SessionRecorder.swift` (`write`, `wavData` — item 1)
- `App/LiveTunerScreen.swift` (`LabelSheet` Save button, the Stop & Save call site — items 1 & 3)
- `Packages/TunerEngine/Sources/TunerEngine/TunerEngine.swift` (`rawSamples` / `clearRawContinuation` — item 2)

## Verification

UI / app-layer only — **not** an accuracy-gated DSP path (no benchmark delta). `xcodebuild test
-scheme LUMA -destination 'platform=macOS'` for the synchronous derivation tests, plus iOS +
macOS builds. The drain/start-stop lifecycle and the main-actor-hang are **not headlessly
testable** (`startRecording` is gated on `running`, which needs a live engine) — verify items
1 & 3 on-device with a longer take; item 2 is reasoning-only (the race is human-unreachable).
Keep everything inside `#if DEBUG`.
