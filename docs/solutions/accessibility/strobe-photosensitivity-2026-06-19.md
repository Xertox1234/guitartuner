# Off-pitch strobe vs WCAG 2.3.1 — photosensitivity analysis (2026-06-19)

**Source rule:** `docs/rules/accessibility.md` (Photosensitivity / C-4).
**Standard:** WCAG 2.3.1 *Three Flashes or Below Threshold* (Level A).
**Scope:** the **default** off-pitch strobe (no accessibility traits set). Reduce
Motion already substitutes `ReducedGauge`, but 2.3.1 is Level A and governs the
**default** experience — an opt-out does not discharge it.

**Verdict: HAZARD.** The default off-pitch strobe can present large-area,
high-contrast luminance reversals well above 3 per second across the normal
tuning range, and cannot be shown to satisfy any WCAG 2.3.1 escape hatch. A
default-mode mitigation is warranted (Task 4b).

---

## 1. Mechanism (verified from code)

Production renders `phaseScroll: true` (`App/LiveTunerScreen.swift:47,67`,
`App/MenuBarTuner.swift:22`). In that mode:

- The engine emits `PitchReading.phase` ∈ [0,1) — a normalized cycle position of
  the tracked fundamental against the nearest-note reference. On pitch it stands
  still; **off pitch it advances at the beat rate (∝ the Hz error)**, unbounded
  by cents (`Packages/TunerEngine/Sources/TunerEngine/PitchReading.swift:10-14`).
- `LiveTunerModel.swift:266` feeds it straight into `StrobeInput.phase` — no rate
  clamp.
- `AuroraStrobe.swift:77-91` derives `scrollVel = wrappedDelta(lastPhase, phase) /
  elapsed` (cycles/sec) and integrates `clock.scroll += scrollVel · dt · (1−lock)`.
  All `ribbonCount` (**13**) ribbons share that single `clock.scroll` offset
  (`:106-117`), so the pattern **translates rigidly**. `scroll` is field-width
  normalized (`pos = … + clock.scroll; pos -= floor(pos); x = pos·w`), so
  **one phase wrap = one full-field translation = one beat cycle.**
- `RadialStrobe.swift:83-96` is the rotational analogue: `rotVel` from the same
  `wrappedDelta`, integrated into one shared `clock.angle` over **36** marks.
- The Metal variants (`MetalStrobe`, `RadialMetalStrobe`) mirror this contract.

**Consequence.** `scrollVel`/`rotVel` ≈ the beat frequency. The whole pattern
sweeps one field-width (Aurora) or one full turn (Radial) per beat cycle. A
**fixed point** is therefore crossed by *N* bright bands per beat cycle:

> per-point flicker = N × beat-rate   (N = 13 Aurora, 36 Radial)

The cents-derived `StrobeMath.scrollSpeed`/`ringSpeed` drive only the
simulator/preview (`phaseScroll: false`) path and are **not** in the live path.

## 2. Worst-case flash rate

Beat rate at the ±50 ¢ detune-window edge is `f·|2^(±50/1200) − 1| ≈ 0.0293·f`:

| Played note | f (Hz) | beat @50¢ (Hz) | Aurora per-point (13×) | Radial per-point (36×) |
|---|---|---|---|---|
| Low B0 (5-str) | ~31 | 0.9 | 11.8 Hz | 32 Hz |
| Bass low E | ~41 | 1.2 | 15.6 Hz | 43 Hz |
| A2 | 110 | 3.2 | 42 Hz | 116 Hz |
| E4 (high open) | 330 | 9.7 | 126 Hz | 348 Hz |
| High fretted | ~660 | 19.3 | 251 Hz | 695 Hz |

Crucially, the **most common** scenario — slightly off and converging — puts the
fixed-region flicker squarely in the **3–30 Hz photosensitive danger band**
(peak provocation ~15–20 Hz). The central region flicker (13×beat) reaches:

- 3 Hz at beat ≈ 0.23 Hz (Aurora) / 0.08 Hz (Radial) — i.e. **almost any audible
  detuning**;
- ~15–20 Hz (peak risk) at beat ≈ 1.2–1.5 Hz (Aurora), which corresponds to a
  few-to-tens of cents off at mid pitches — a routine tuning state.

The whole-field rigid-translation rate (one bright band crossing center) is the
beat rate itself, 0–~19 Hz, exceeding 3 Hz above ~A2 at the detune edge.

## 3. Concurrent bright-area fraction (the traveling-wave argument, quantified)

A rigid translating grating has **constant total luminance** — so the
*whole-screen integral* does not flash. WCAG, however, asks whether any region
≳25% of the central 10° field undergoes a synchronized ≥10% reversal.

At a typical phone viewing distance the screen subtends ~35°, so the 13 Aurora
ribbons have an angular period ≈ 35°/13 ≈ **2.7°**, and the WCAG threshold area
(0.006 sr ≈ a ~5° patch, ~25% of the 10° central field) spans ≈ 1.85 ribbon
periods. The *residual* synchronized modulation depth over such a patch is
**model-dependent** — a continuous sinc average gives ~8% (which would argue
below-threshold), while discrete band-counting (~1.5↔2.2 bands in the patch)
gives 30–50%. That spread is exactly the point: **the area exemption is not a
default; it must be affirmatively demonstrated.** The traveling-wave structure
reduces flash *synchrony* (the whole-screen integral is near-constant), but it
does **not** reduce flash *area* — bright, full-height bands sweep across far more
than 25% of the central field, and a full-screen high-contrast translating
grating cannot be shown to keep every ≥25% region below the 10%-of-max reversal
bar across the operating range. Radial is worse: 36 marks with a brightness
envelope (`StrobeMath.markEnvelope`) swept toward the ring top concentrate a
larger synchronized area.

Net: the spatial structure spares the *whole-screen integral* but cannot
establish the area exemption for any large central region; the high-contrast
reversals (§4) at N×beat (§2) remain.

## 4. Luminance delta

Off pitch (`lock = 0`, dark scheme, `.plusLighter` additive blend), the brightest
ribbon alpha is `a = (0.10 + 0.5·env) ≈ 0.60` at the center
(`AuroraStrobe.swift:113`), plus the central column (`:121`). Using the WCAG sRGB
relative-luminance formula (same as `ContrastAuditTests`):

- mint tune `#28F0C0` rel-luminance ≈ **0.666**; at α≈0.6 additive over near-black
  → peak ≈ **0.40**.
- inter-ribbon trough ≈ background `#0A0B10` ≈ **0.003**.

Peak↔trough swing ≈ 0.40 (darker image 0.003 < 0.80; change ≫ 10% of max). The
luminance delta **massively exceeds** the WCAG flash threshold; the high-contrast
condition is unambiguously met.

## 5. WCAG 2.3.1 determination

Compliance requires one escape hatch; none holds:

1. **≤3 flashes/sec?** No — fixed-region flicker is N×beat = 13–700 Hz across the
   range, exceeding 3/sec for essentially any audible detuning.
2. **Flashing area <25% of the central 10° field?** No — the strobe is
   full-screen; bright bands sweep across far more than 25% of the field.
3. **Luminance delta <10% of max?** No — peak↔trough ≈ 0.40 (§4).

The traveling-wave structure spares the *whole-screen integral* but not the
*regional* reversals WCAG's area criterion targets, and it leaves the
high-contrast danger-band flicker intact at the most common tuning states.
**Conclusion: HAZARD.**

## 6. Recommended mitigation (for Task 4b)

The goal: keep no large-area, high-contrast reversal in the >3 Hz range in the
default experience, while preserving the in-tune lock moment (which is already
static — `lock` eases velocity to 0 — and is not the hazard).

Two independent levers; **a naive `scrollVel ≤ 3 Hz` clamp is INSUFFICIENT** —
per-region flicker is N×scrollVel, so clamping translation to 3 cycles/sec still
yields 13×3 = 39 Hz Aurora flicker. The viable levers are:

- **(A) Cap the per-region flicker** by clamping the translation rate to
  `≤ 3/N` cycles/sec (Aurora ≤ 0.23, Radial ≤ 0.083). Keeps full contrast but
  makes off-pitch drift very slow (still directional, but no longer a fast
  strobe). Simple; visibly changes the signature motion.
- **(B) Cap the luminance delta in the danger band** — when the effective region
  flicker (N×beat) would exceed 3 Hz, reduce ribbon/mark alpha so the per-reversal
  luminance change stays below the 10%-of-max flash threshold. Preserves motion;
  dims the off-pitch field. Requires the renderers to derive an effective flicker
  rate and attenuate alpha accordingly.
- **(C) A blend:** modest rate cap + danger-band alpha attenuation.

Lever choice materially affects the product's signature visual experience, so the
**approach is a design decision to confirm with the product owner**, not a pure
mechanical clamp. Whichever is chosen, 4b touches the Canvas renderers and the
Metal shaders (preserve the triple-buffer contract and 120 fps) and must keep the
on-pitch/lock path byte-identical (the clamp bites only at high beat rates).

---

## 7. Mitigation applied (C-4b, 2026-06-20) — Lever C (blend)

Implemented per the product owner's choice (rate ceiling + danger-band dim),
**entirely CPU-side** — the embedded MSL is unchanged (both Metal shaders already
multiply the whole luminous accumulation by `U.dim`, so the guard folds into that
uniform; the triple-buffer path and 120 fps are untouched).

Pure helpers in `StrobeMath` (unit-tested by the *compliance invariant*, not clamp
mechanics, in `PhotosensitivityClampTests`):
- `clampedStrobeRate(_:)` — caps |translation/rotation rate| to `maxStrobeRateHz`
  (4.0 cycles/sec; **aesthetic** ceiling on visible drift speed, engineering
  judgement — not the safety mechanism).
- `photosensitivityBrightness(rateHz:ribbonCount:)` — the **safety** mechanism:
  full vividness while region flicker (`N × rate`) ≤ 2 Hz, ramping to
  `shimmerFloor = flashLuminanceFraction / peakLuminanceSwing = 0.10 / 0.40 = 0.25`
  by the 3 Hz limit. So at all times either flicker ≤ 3/sec OR swing ≤ 10% of max
  — compliant **by construction** given the §4 luminance model. `0.25` is a
  *visible low-contrast shimmer*, not darkness; direction + motion stay readable.

Applied in all four full-screen renderers — `AuroraStrobe`, `RadialStrobe`
(Canvas: multiply ribbon/mark + central-column alpha), `MetalStrobe`,
`RadialMetalStrobe` (fold into `dim`). The guard is driven by the **lock-eased**
effective rate, so it vanishes at lock (`→ 1`) and the in-tune bloom is
byte-identical (honors `strobe.md` lock trip-wire). The menu-bar strobe is
*area-exempt* (well below the 25%-of-central-field threshold) and is not modified.

**Verification scope (honest):** the unit test proves the safety *logic* given the
§4 luminance model (peak swing ≈ 0.40); it is **not** an on-device flash
measurement, and the rate ceiling is a feel choice. The off-pitch (non-phase /
simulator) preview path is out of scope (the live tuner always uses
`phaseScroll: true`).

---

*Standard reference:* WCAG 2.2 SC 2.3.1 and the W3C definitions of *general
flash*, *flash*, and the 0.006 sr / 25%-of-10°-central-field area threshold
(<https://www.w3.org/TR/WCAG22/#three-flashes-or-below-threshold>,
<https://www.w3.org/TR/WCAG22/#dfn-general-flashes-and-red-flashes>).

*Method note:* relative luminance and the danger-band reasoning use the WCAG 2.x
sRGB formula in `Packages/LumaDesignSystem/Tests/LumaDesignSystemTests/ContrastAuditTests.swift`.
Numbers are order-of-magnitude where viewing distance / device geometry enters;
the determination does not hinge on the exact decimals — the rate exceeds 3/sec
and the contrast exceeds 10% of max by large margins across the operating range.
