import Foundation
import Observation
import LumaDesignSystem
import TunerEngine

/// Drives the live Tuner screen from the real `TunerEngine`: owns the engine, the
/// reference-tone generator, and the lock haptic; consumes the engine's
/// `AsyncStream<PitchReading>` on the main actor; and republishes the bits the
/// SwiftUI views need (the `StrobeInput`, note/cents/Hz, targeting state, status).
///
/// This is the app-layer glue (DESIGN §5): the engine stays UI-free and the design
/// system stays logic-free — the mode/target/tone/haptic policy lives here.
///
/// **String-lock (DESIGN §2.4):** in `.lock` mode the engine's `targetNote` is set
/// so the strobe phase references the chosen string, and the readouts are computed
/// *relative to that target* (`Note.cents(of:)`) — judging only that one pitch, the
/// robust path for low B/E. In `.auto` mode it's chromatic nearest-note.
@MainActor
@Observable
final class LiveTunerModel {
    // MARK: Readout state
    /// The strobe render contract (carries the live `phase`).
    private(set) var strobeInput = StrobeInput()
    private(set) var note: String = "–"
    private(set) var octave: Int = 4
    /// `nil` when there's no confident pitch (idle / silence).
    private(set) var cents: Double?
    private(set) var frequency: Double = 0
    private(set) var confidence: Double = 0
    private(set) var running = false
    private(set) var status: String = "Tap Start to listen"
    /// Mic access was denied/restricted — the screen offers a System Settings link.
    private(set) var permissionDenied = false

    // MARK: Targeting / tuning
    private(set) var instrument: Instrument = .guitar
    private(set) var tuning: Tuning = Tunings.standard(for: .guitar)
    private(set) var mode: TargetMode = .auto
    /// The selected string's `idx` (string-lock target / tone source); `nil` = none.
    private(set) var activeIdx: Int?
    @ObservationIgnored private(set) var targetNote: Note?

    // MARK: Tone + feel
    var toneOn = false { didSet { updateTone() } }
    @ObservationIgnored @AppStorage("hapticsEnabled") var hapticsEnabled = true
    private(set) var inputKind: InputKind = .di

    /// Adjustable reference pitch (430…450, default 440), shared by engine + tone.
    var a4: Double = 440 { didSet { applyA4() } }
    @ObservationIgnored @AppStorage("a4Calibration") private var storedA4: Double = 440

    var idle: Bool { cents == nil }

    /// The currently-selected string, if any.
    var activeString: GuitarString? {
        guard let activeIdx else { return nil }
        return tuning.strings.first { $0.idx == activeIdx }
    }

    @ObservationIgnored private let engine = TunerEngine()
    @ObservationIgnored private let tone = ToneGenerator()
    @ObservationIgnored private let haptics = LockHaptics()
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var lastUpdate = Date.distantPast
    @ObservationIgnored private var lockGate = LockGate()

    init() {
        // didSet not called during init; engine.setA4 is called on start().
        self.a4 = storedA4
    }

    // MARK: - Lifecycle

    /// Start capture + analysis. Surfaces permission / availability errors as
    /// `status` rather than throwing into the view.
    func start() async {
        guard !running else { return }
        haptics.prepare()
        tone.prepare()
        do {
            await engine.setA4(a4)
            await engine.setInputPreference(inputKind == .mic ? .mic : .auto)
            await engine.setTargetNote(targetNote)
            try await engine.start()
            running = true
            permissionDenied = false
            status = "Listening"
            readTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await reading in await self.engine.readings {
                    self.apply(reading)
                }
            }
            startWatchdog()
        } catch {
            running = false
            permissionDenied = (error as? TunerEngineError) == .microphonePermissionDenied
            status = (error as? TunerEngineError)?.errorDescription
                ?? "Live audio unavailable: \(error.localizedDescription)"
        }
    }

    func stop() {
        running = false
        readTask?.cancel(); readTask = nil
        watchdog?.cancel(); watchdog = nil
        cents = nil
        lockGate.reset()
        status = "Stopped"
        let e = engine                      // capture the actor, not self
        Task { await e.stop() }
    }

    func toggle() async {
        if running { stop() } else { await start() }
    }

    // MARK: - Targeting

    func setMode(_ newMode: TargetMode) {
        mode = newMode
        // Entering string-lock with nothing chosen targets the lowest string, so
        // the strobe immediately judges something useful.
        if newMode == .lock, activeIdx == nil {
            activeIdx = tuning.strings.first?.idx
        }
        updateTarget()
    }

    /// Tap a string: it becomes the active string (string-lock target and/or tone
    /// source). In `.auto` mode this only arms the tone source — the strobe stays
    /// chromatic until you switch to `.lock`.
    func selectString(_ idx: Int) {
        activeIdx = idx
        lockGate.reset()
        updateTarget()
        updateTone()
    }

    func setInstrument(_ newValue: Instrument) {
        guard newValue != instrument else { return }
        instrument = newValue
        setTuning(Tunings.standard(for: newValue))
    }

    func setTuning(_ newTuning: Tuning) {
        tuning = newTuning
        // Keep the selection valid across a string-count change.
        if let idx = activeIdx, !newTuning.strings.contains(where: { $0.idx == idx }) {
            activeIdx = newTuning.strings.first?.idx
        }
        updateTarget()
        updateTone()
    }

    func setInputKind(_ kind: InputKind) {
        guard kind != inputKind else { return }
        inputKind = kind
        let e = engine
        let pref: InputPreference = (kind == .mic) ? .mic : .auto   // DI chip = DI-first auto
        Task { await e.setInputPreference(pref) }
        if running { status = "Restart to apply \(kind.label) input" }
    }

    private func updateTarget() {
        let target: Note? = (mode == .lock) ? activeString.map { Note(midi: $0.midi) } : nil
        targetNote = target
        // Show the targeted note straight away (dimmed when idle) so the user can
        // see which string they're tuning before they pluck.
        if let target {
            note = target.name
            octave = target.octave
        }
        let e = engine
        Task { await e.setTargetNote(target) }
    }

    // MARK: - Tone

    /// The note the tone sounds: the active string at the current A4, else the bare
    /// A4 reference as a sensible fallback.
    private var toneFrequency: Double {
        if let s = activeString { return Note(midi: s.midi).frequency(a4: a4) }
        return a4
    }

    private func updateTone() {
        tone.setActive(toneOn, frequency: toneFrequency)
    }

    // MARK: - Reference calibration

    private func applyA4() {
        let clamped = min(450, max(430, a4))
        if clamped != a4 { a4 = clamped }   // in-place clamp; doesn't re-fire didSet
        storedA4 = clamped
        let e = engine
        Task { await e.setA4(clamped) }
        updateTone()                         // keep the tone on pitch
    }

    // MARK: - Reading → display

    private func apply(_ r: PitchReading) {
        if mode == .lock, let target = targetNote {
            // Judge only the targeted string: cents relative to it, phase already
            // referenced to it by the engine. Octave errors can't cause a false
            // lock here because a wrong octave lands far outside lockCents.
            let c = target.cents(of: r.frequency, a4: a4)
            let locked = abs(c) <= LumaMusic.lockCents && r.confidence >= r.minLockConfidence
            note = target.name
            octave = target.octave
            cents = c
            frequency = r.frequency
            confidence = r.confidence
            strobeInput = StrobeInput(cents: c, phase: r.phase, locked: locked)
            handleLock(locked, noteFreq: target.frequency(a4: a4))
        } else {
            // Chromatic nearest-note.
            note = r.note.name
            octave = r.note.octave
            cents = r.cents
            frequency = r.frequency
            confidence = r.confidence
            let si = r.strobeInput()
            strobeInput = si
            handleLock(si.locked, noteFreq: r.note.frequency(a4: a4))
        }
        lastUpdate = Date()
    }

    /// Fire the in-tune haptic and confirmation ping on the rising edge into lock.
    /// The visual bloom is driven by the readouts' `locked` state independently.
    private func handleLock(_ locked: Bool, noteFreq: Double) {
        let (haptic, ping) = lockGate.step(locked: locked)
        if haptic, hapticsEnabled { haptics.tap() }
        if ping, !toneOn { tone.ping(frequency: noteFreq) }
    }

    /// Fade to idle when readings stop arriving (note released / silence), so the
    /// strobe rests in its breathing attract state instead of freezing on a stale value.
    private func startWatchdog() {
        watchdog = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)   // 120 ms
                guard let self else { return }
                if self.running, Date().timeIntervalSince(self.lastUpdate) > 0.35 {
                    self.cents = nil
                    self.lockGate.reset()
                }
            }
        }
    }
}
