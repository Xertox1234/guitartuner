# LUMA — Build Plans

Session-ready plans for the first three engineering workstreams. Each is **self-contained
and meant to be executed in its own focused session.** Read the canonical docs first, then
the specific plan, then build.

## Canonical context (read first, every session)
- [`DESIGN.md`](../../DESIGN.md) — product, accuracy, privacy, scope
- [`docs/EXPERIENCE.md`](../EXPERIENCE.md) — the experience pillar
- [`docs/design_reference/DESIGN_SYSTEM.md`](../design_reference/DESIGN_SYSTEM.md) — LUMA tokens & components
- [`docs/design_reference/`](../design_reference/) — the raw design export (CSS/JSX + screenshots)

## The three workstreams
| # | Plan | Depends on | Can start |
|---|---|---|---|
| 1 | [`TunerEngine` — DSP + benchmark](01-tuner-engine.md) | none | anytime (parallel) |
| 2 | [SwiftUI design-system scaffold](02-swiftui-design-system.md) | none | anytime; natural base for #3 |
| 3 | [First strobe prototype (Aurora)](03-strobe-prototype.md) | #2 ideally | after/with #2 |

Suggested order: **#2 → #3** (the strobe wants the colour/type tokens), with **#1 in
parallel** whenever. Each plan ends with a copy-paste **kickoff prompt** for its session.

## Ground rules
- These are **planning artifacts** — the actual Swift code is produced in each workstream's
  own session.
- Native **SwiftUI multiplatform** (iPhone/iPad/Mac, *not* Catalyst); **no networking** in v1.
- Keep `TunerEngine` UI-free and independently testable; keep the design system logic-free.
