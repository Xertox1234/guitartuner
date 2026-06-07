# Project memory — guitartuner (LUMA)

## Repository & CI
- The repo is **public**, so GitHub Actions (including the 10× `macos-14`
  runners) is **free**. CI in `.github/workflows/ci.yml` runs automatically on
  `push` and `pull_request` (plus manual `workflow_dispatch`).
- **Auto-merge is enabled.** Open PRs are set to merge automatically once
  required CI passes — so getting CI green is what lands a PR; no manual merge
  click is needed.
- Default branch is `claude/peaceful-mccarthy-LNxPa` (not `main`) — target PRs
  there.

## Testing
- Web (Linux) sessions auto-install the Swift toolchain via
  `.claude/hooks/session-start.sh`, so the engine can be tested in-session for
  free: `swift test --package-path Packages/TunerEngine` plus the accuracy
  benchmark. SwiftUI/Xcode app builds are macOS-only (the CI `app` job).
