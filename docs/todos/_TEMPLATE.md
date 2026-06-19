---
priority: P2          # P0 blocker · P1 high · P2 medium · P3 low (MUST match the P<n>- filename prefix)
status: open          # open · needs-spec · partial · blocked
domain: dsp           # dsp · pipeline · capture · strobe · swiftui · design-system · testing · security · accessibility · hooks · other
source:               # audit / spec / PR that surfaced it (optional)
depends_on:           # another todo or work this waits on (optional)
---

<!-- Copy this file to docs/todos/P<n>-<slug>.md, then delete this line. _TEMPLATE.md is not itself a todo. -->

# <Title: what + why, in one line>

## Problem

<What's wrong or missing, and why it matters. Concrete symptoms beat abstractions.>

## Fix

<Concrete steps. Call out any decisions that must be made before/while implementing.>

## Files

- `path/to/File.swift` (symbol / ~line)

## Verification

<Test command(s). Is this an accuracy-gated DSP path? If so, note the benchmark
zero-delta requirement. UI-only? Note what's headlessly testable vs simulator-only.>
