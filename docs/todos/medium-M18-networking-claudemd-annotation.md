# Networking in app without CLAUDE.md annotation — creates ambiguous audit signal

**Severity:** Medium  
**Audit:** 2026-06-15-full  
**Domain:** cross-cutting

## Problem

CLAUDE.md states "no networking in v1." A full URLSession backend (`LumaAPI`) exists and is wired at app launch. Audio data does not flow through it. The rule must be clarified to prevent future false-positive audit signals.

## Fix

- Update CLAUDE.md to explicitly note that `LumaAPI` is the intentional monetization backend
- Distinguish the audio-privacy invariant (on-device) from the permitted opt-in account networking
- Add a section documenting the network boundary and what data flows where

## Files

- `CLAUDE.md`
