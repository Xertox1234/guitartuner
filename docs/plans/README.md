# LUMA — Build Plans

Session-ready plans for the first three engineering workstreams. Each is **self-contained
and meant to be executed in its own focused session.** Read the canonical docs first, then
the specific plan, then build.

## Canonical context (read first, every session)
- [`DESIGN.md`](../../DESIGN.md) — product, accuracy, privacy, scope
- [`docs/EXPERIENCE.md`](../EXPERIENCE.md) — the experience pillar
- [`docs/design_reference/DESIGN_SYSTEM.md`](../design_reference/DESIGN_SYSTEM.md) — LUMA tokens & components
- [`docs/design_reference/`](../design_reference/) — the raw design export (CSS/JSX + screenshots)
- [`docs/ROADMAP.md`](../ROADMAP.md) — **the living backlog**: what's left, on-device checks, open decisions

## The workstreams
| # | Plan | Depends on | Can start | Status |
|---|---|---|---|---|
| 1 | [`TunerEngine` — DSP + benchmark](01-tuner-engine.md) | none | anytime (parallel) | shipped |
| 2 | [SwiftUI design-system scaffold](02-swiftui-design-system.md) | none | anytime; base for #3 | shipped |
| 3 | [First strobe prototype (Aurora)](03-strobe-prototype.md) | #2 ideally | after/with #2 | shipped |
| 4 | Tuner UX (string-lock, presets, A4, tone, haptics) | #1–#3 | — | shipped |
| 5 | Radial strobe + style toggle | #3 | — | shipped |
| 6 | [**Project Strobe-Grade — the accuracy ceiling**](06-accuracy-engine.md) | #1 | now | **planned** |

Suggested original order was **#2 → #3** (the strobe wants the colour/type tokens), with
**#1 in parallel**. With v1's eight features shipped, **#6 is the flagship next push**:
take Pillar I (accuracy — the product's reason to exist) to its physical ceiling, in
benchmark-gated phases. Each plan ends with a copy-paste **kickoff prompt** for its
session.

## Ground rules
- These are **planning artifacts** — the actual Swift code is produced in each workstream's
  own session.
- Native **SwiftUI multiplatform** (iPhone/iPad/Mac, *not* Catalyst); **no networking** in v1.
- Keep `TunerEngine` UI-free and independently testable; keep the design system logic-free.
