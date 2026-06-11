# Release readiness

What stands between a green CI and a submittable build.

- [ ] **Set `DEVELOPMENT_TEAM`** in `project.yml` (then `xcodegen generate`).
- [ ] **Decide the deployment floor** — currently iOS 17 / macOS 14, still marked
      TBD in `docs/ROADMAP.md` § Open decisions. Decide and remove the TBD.
- [ ] **Version & build numbering** — `MARKETING_VERSION` is `0.1.0`; pick the
      v1.0 scheme and how `CURRENT_PROJECT_VERSION` increments for TestFlight.
- [ ] **App Store metadata** — name/subtitle, description leaning on the two
      pillars (measured accuracy + the strobe), screenshots (Stage Mode and the
      menu-bar tuner are the showpieces), keywords, $9.95 one-time price.
- [ ] **Privacy nutrition label** — should be the easiest in the store: no data
      collected, no tracking, no network. Double-check the questionnaire answers
      match "collects nothing".
- [ ] **TestFlight pass** — internal build on iPhone/iPad/Mac before review.
- [ ] **Direct-distribution decision (macOS)** — App Store only, or also a
      notarized Developer-ID build? The hardened runtime + entitlements are
      already in place either way.
