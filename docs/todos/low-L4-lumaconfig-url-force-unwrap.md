# Force-unwrap on static URL literal in LumaConfig

**Severity:** Low  
**Audit:** 2026-06-15-full  
**Domain:** swiftui

## Problem

`URL(string: "https://...")!` violates the no-force-unwrap rule. A well-formed literal can't return nil but the rule is unconditional.

## Fix

- Use `URL(string:).unsafelyUnwrapped` with a comment explaining why the URL is guaranteed to be valid, or
- Use a compile-checked literal helper (if one exists in the codebase)

## Files

- `App/Networking/LumaConfig.swift` (line 4)
