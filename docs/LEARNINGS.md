# LUMA — Learnings

Non-obvious discoveries from development, newest first. Detailed write-ups live in `docs/solutions/`.

<!-- Format: - YYYY-MM-DD: [one-liner] → [link to solution file if written] -->
- 2026-06-12: macOS sandboxed/hardened-runtime builds silently fail at `AVAudioEngine.start()` (not at the permission check) when `com.apple.security.device.audio-input` entitlement is missing → [solutions/macos-audio-input-entitlement-2026-06-12.md](solutions/macos-audio-input-entitlement-2026-06-12.md)
- 2026-06-12: macOS Settings deep link for mic privacy is an undocumented compat shim — works via `openURL`/`NSWorkspace` but has no Apple stability guarantee; verify on each major OS release → [solutions/mic-permission-denied-settings-deeplink-2026-06-12.md](solutions/mic-permission-denied-settings-deeplink-2026-06-12.md)
