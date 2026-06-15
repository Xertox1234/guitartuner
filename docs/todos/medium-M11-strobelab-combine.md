# StrobeLab uses Combine (Timer.publish) — violates Swift Concurrency project rule

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** strobe / design-system

## Problem

`Timer.publish(every:on:in:).autoconnect()` with `.onReceive()` drives the physics tick. Project rule mandates Swift Concurrency everywhere, no Combine.

## Fix

- Replace with `TimelineView(.animation(minimumInterval: 1.0/120.0))` for 120fps timing
- Alternatively, use a `.task`-based `AsyncStream` tick
- Remove the Combine import and verify no other Combine code remains in the file

## Files

- `Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/StrobeLab.swift` (line 20)
