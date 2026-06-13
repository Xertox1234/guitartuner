# On-device verification pass

CI compiles everything and runs the headless DSP, but live audio, haptics, and
GPU frame rates need real hardware. Mirrors `docs/ROADMAP.md` § On-device
verification — tick both when done. Needs at least one iPhone (ideally with a
ProMotion panel) and one Mac.

- [ ] **Live capture** — DI-preferred + mic fallback on iOS *and* macOS hardware;
      confirm the input-source chip (DI/Mic) actually swaps devices.
- [ ] **Permission flow** — first-run mic prompt appears with the privacy copy;
      deny it, confirm the status message + the new **"Open Settings" deep link**
      lands on the right pane (app page on iOS, Privacy → Microphone on macOS),
      and that re-granting + tapping Start recovers cleanly.
- [ ] **Entitlements** — a signed, sandboxed macOS build (`App/LUMA.entitlements`:
      App Sandbox + `com.apple.security.device.audio-input`) can open the mic;
      notarization passes with the hardened runtime.
- [ ] **Tone while listening** — `ToneGenerator` switches the iOS session to
      `.playAndRecord`; confirm no capture glitch and AGC stays off the analysis
      path. *(Flagged during Plan 04.)*
- [ ] **Core Haptics** — the in-tune lock tap on iPhone/iPad; clean no-op on Mac.
- [ ] **Metal hero (`MetalStrobe`)** — matches the Canvas Aurora look, holds
      **120 fps** on ProMotion (Strobe lab fps readout), light/dark blends read
      right, Settings toggle swaps cleanly.
- [ ] **Fonts** — bundled Chakra Petch / JetBrains Mono actually rasterize on
      device (CI can only verify registration).
- [ ] **Menu-bar tuner** — live ring + caption glyph on a real Mac; consider the
      deferred in-bar animated ring while there.
