# DispatchQueue.main.async in SwiftUI view — GCD in a @MainActor context

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

`DispatchQueue.main.async { showDeleteConfirm = true }` is GCD inside a `@MainActor` SwiftUI view. This mixes concurrency models unnecessarily; the code already runs on the main thread.

## Fix

- Replace with `Task { @MainActor in showDeleteConfirm = true }`
- Review the entire file for other GCD calls that should be converted to Swift Concurrency

## Files

- `App/Views/Monetization/BottomDrawer.swift` (line 116)
