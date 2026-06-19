## Summary

<!-- what & why -->

## Accessibility (delete rows that don't apply)
- [ ] Reduce Motion honored (ReducedGauge fallback where animated)
- [ ] Reduce Transparency honored (bloom / wash attenuated)
- [ ] Dynamic Type scales chrome/settings text (or opt-out documented)
- [ ] accessibilityLabel on interactive elements; live accessibilityValue on pitch views
- [ ] No color-only state; differentiateWithoutColor honored
- [ ] WCAG AA contrast in both light and dark
- [ ] (Strobe/animation) checked vs WCAG 2.3.1 flash threshold

## Security
- [ ] No networking outside LumaAPI; HTTPS only (no ATS exception)
- [ ] Secrets in Keychain (…ThisDeviceOnly), not UserDefaults/cache
- [ ] No PII/secrets in print/logs (os.Logger + .private)
