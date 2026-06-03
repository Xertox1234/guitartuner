import Foundation
import Observation
import LumaDesignSystem
import TunerEngine

/// Drives the live Tuner screen from the real `TunerEngine`: owns the engine,
/// consumes its `AsyncStream<PitchReading>` on the main actor, and republishes the
/// bits the SwiftUI views need — the `StrobeInput`, note/cents/Hz, and a coarse
/// status. This is the app-layer glue that *replaces* `TunerSimulator` for live
/// use (Plan 01 wiring); the engine itself stays UI-free.
@MainActor
@Observable
final class LiveTunerModel {
    /// The strobe render contract (carries the live `phase`).
    private(set) var strobeInput = StrobeInput()
    private(set) var note: String = "–"
    private(set) var octave: Int = 4
    /// `nil` when there's no confident pitch (idle / silence).
    private(set) var cents: Double?
    private(set) var frequency: Double = 0
    private(set) var confidence: Double = 0
    private(set) var running = false
    private(set) var status: String = "Tap to start"

    /// Adjustable reference pitch (430…450, default 440).
    var a4: Double = 440 {
        didSet {
            let clamped = min(450, max(430, a4))
            if clamped != a4 { a4 = clamped }     // setting within didSet won't re-fire it
            let e = engine                        // capture the actor, not self
            Task { await e.setA4(clamped) }
        }
    }

    var idle: Bool { cents == nil }

    @ObservationIgnored private let engine = TunerEngine()
    @ObservationIgnored private var readTask: Task<Void, Never>?
    @ObservationIgnored private var watchdog: Task<Void, Never>?
    @ObservationIgnored private var lastUpdate = Date.distantPast

    /// Start capture + analysis. Surfaces permission / availability errors as
    /// `status` rather than throwing into the view.
    func start() async {
        guard !running else { return }
        do {
            await engine.setA4(a4)
            try await engine.start()
            running = true
            status = "Listening"
            readTask = Task { @MainActor [weak self] in
                guard let self else { return }
                for await reading in self.engine.readings {
                    self.apply(reading)
                }
            }
            startWatchdog()
        } catch {
            running = false
            status = (error as? TunerEngineError)?.errorDescription
                ?? "Live audio unavailable: \(error.localizedDescription)"
        }
    }

    func stop() {
        running = false
        readTask?.cancel(); readTask = nil
        watchdog?.cancel(); watchdog = nil
        cents = nil
        status = "Stopped"
        let e = engine                      // capture the actor, not self
        Task { await e.stop() }
    }

    func toggle() async {
        if running { stop() } else { await start() }
    }

    private func apply(_ r: PitchReading) {
        note = r.note.name
        octave = r.note.octave
        cents = r.cents
        frequency = r.frequency
        confidence = r.confidence
        strobeInput = r.strobeInput()
        lastUpdate = Date()
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
                }
            }
        }
    }
}
