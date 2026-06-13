# UX follow-ups & small decisions

Low-urgency polish and open product decisions noted in the completeness review.

- [ ] **Auto-restart on input switch** — changing the DI/Mic chip mid-session
      currently shows "Restart to apply" (`LiveTunerModel.setInputKind`). Restart
      the engine automatically instead (stop → set preference → start), keeping
      the strobe's idle state during the swap.
- [ ] **Localization decision** — `SWIFT_EMIT_LOC_STRINGS: YES` is set but there
      are no string catalogs; the app is English-only. Decide: ship v1 English-only
      (fine) or add a `Localizable.xcstrings` now while the string count is small.
- [ ] **`prototypes/` cleanup** — `strobe-concepts.html` predates the in-app
      Strobe lab. Keep as a design artifact or delete?
- [ ] **Bass worst-case tail** — the P2 residual gate (worst ≤3 ¢, currently
      5.81 ¢ max). Tracked in `docs/ROADMAP.md` § Accuracy ceiling; listed here
      because it's also the one number a reviewer could ding.
- [ ] **`FreqLine` algo caption** — the readout hardcodes `algo: "MPM", rate: "48k"`.
      MPM is still the octave authority so it's not *wrong*, but consider whether
      the caption should reflect the spectral/comb precision stack (or be dropped).
