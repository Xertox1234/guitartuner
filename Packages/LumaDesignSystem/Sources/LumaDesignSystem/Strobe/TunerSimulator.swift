import Foundation
import Observation

/// Drives a live, interactive tuning simulation so the strobe needs **no audio
/// engine** — pluck a string → a fresh out-of-tune reading that converges to
/// lock (simulating turning the peg), with micro string wobble that fades.
/// Ported from `useTunerSim` in `docs/design_reference/strobe-core.jsx`.
///
/// Advance physics with `advance(to:)` ~once per frame (from a timer, off the
/// view-update path). The real `TunerEngine` (Plan 01) replaces this, feeding
/// the same `StrobeInput`.
@Observable
public final class TunerSimulator {
    public private(set) var instrument: Instrument
    public private(set) var stringIdx: Int
    public private(set) var cents: Double
    /// While true, physics converges toward `target`; the manual slider pauses it.
    public private(set) var running: Bool = true

    private var target: Double = 0
    private var wobble: Double = 0
    private var lastTime: Double = 0

    public init(instrument: Instrument = .guitar) {
        self.instrument = instrument
        let tuning = Tunings.standard(for: instrument)
        self.stringIdx = tuning.strings[tuning.strings.count / 2].idx
        self.cents = -18
    }

    public var tuning: Tuning { Tunings.standard(for: instrument) }

    public var activeString: GuitarString {
        tuning.strings.first { $0.idx == stringIdx } ?? tuning.strings[0]
    }

    public var locked: Bool { abs(cents) < LumaMusic.lockCents }

    public var input: StrobeInput { StrobeInput(cents: Float(cents), phase: 0, locked: locked, isIdle: false) }

    public func displayedFrequency(a4: Double = 440) -> Double {
        LumaMusic.frequency(midi: activeString.midi, a4: a4) * pow(2, cents / 1200)
    }

    /// Pluck/select a string → jump out of tune, then converge.
    public func pluck(_ idx: Int? = nil) {
        if let idx { stringIdx = idx }
        cents = (Bool.random() ? -1 : 1) * (15 + Double.random(in: 0..<28))
        target = 0
        running = true
    }

    /// Switch instrument and reset to a fresh out-of-tune reading on its middle string.
    public func setInstrument(_ newValue: Instrument) {
        guard newValue != instrument else { return }
        instrument = newValue
        resetForInstrument()
    }

    /// Manual override (the cents slider) — hold exactly where the user puts it.
    public func setManual(_ value: Double) {
        cents = max(-LumaMusic.trackCents, min(LumaMusic.trackCents, value))
        target = cents
        running = false
    }

    /// Integrate convergence + wobble up to absolute `time` (seconds).
    public func advance(to time: Double) {
        defer { lastTime = time }
        guard lastTime != 0 else { return }          // establish a baseline first
        let dt = min(0.05, time - lastTime)
        guard running, dt > 0 else { return }

        var c = cents
        // approach target (0), easing as we close in — "turning the peg"
        let toGo = target - c
        let step = (toGo < 0 ? -1.0 : 1.0) * min(abs(toGo), (8 + abs(toGo) * 0.9) * dt * 6)
        c += step
        // micro string wobble, fades toward lock
        wobble += dt
        let wobAmp = abs(c) > LumaMusic.lockCents ? min(1.6, 0.4 + abs(c) * 0.03) : 0.25
        c += sin(wobble * 11) * wobAmp * dt * 8 * (Double.random(in: 0..<0.6) + 0.7)
        cents = max(-LumaMusic.trackCents, min(LumaMusic.trackCents, c))
    }

    private func resetForInstrument() {
        let tuning = Tunings.standard(for: instrument)
        stringIdx = tuning.strings[tuning.strings.count / 2].idx
        cents = (Bool.random() ? -1 : 1) * (16 + Double.random(in: 0..<24))
        target = 0
        running = true
    }
}
