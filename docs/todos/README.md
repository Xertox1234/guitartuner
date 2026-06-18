# LUMA todos

The running backlog of **open** work. Canonical intent lives in `DESIGN.md` /
`docs/EXPERIENCE.md` / `docs/plans/`; this directory is the task list.

## Conventions

- **One file per todo.** Filename: `P<n>-<short-kebab-slug>.md`.
- **Priority by severity** (the `P<n>-` prefix, mirrored in frontmatter `priority:`):
  - `P0` — blocker / ship-stopper (CI red, data loss, crash on launch)
  - `P1` — high (core accuracy/UX; do next)
  - `P2` — medium (quality, correctness nits, missing tests)
  - `P3` — low (polish, latent footguns, perf nits)
- **Start from the template:** copy `_TEMPLATE.md`. Frontmatter `priority` MUST
  match the filename prefix. Set `status:` (`open` · `needs-spec` · `partial` · `blocked`).
- **Completion = move, not delete.** When a todo is done, `git mv` it into
  `archive/` — never delete it. This preserves the "why/how it was resolved" trail.
  (The failure that motivated this convention: completed todos were silently
  deleted, then re-"discovered" as phantom-open in a later sweep.)
- **Verify before acting.** These files go stale — a `/todo` run must check each
  open todo against current code before working it, not trust the prose.

## Not todos

`README.md`, `_TEMPLATE.md` (leading `_`), and everything under `archive/` are
**not** backlog items — skip them when listing open work.
