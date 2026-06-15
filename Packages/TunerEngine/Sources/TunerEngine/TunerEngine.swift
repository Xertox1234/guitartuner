import Foundation

/// The public, actor-isolated tuner. Live audio (on-device) flows
/// `tap → ring buffer → pipeline`, emitting `PitchReading`s on an `AsyncStream`.
/// Chromatic by default; an optional `targetNote` hint references the strobe to a
/// specific string for string-lock (Plan 01 §5).
///
/// ```swift
/// let engine = TunerEngine()
/// try await engine.start()
/// for await reading in await engine.readings {
///     // note, cents, confidence, phase …
/// }
/// ```
///
/// The DSP lives in `PitchPipeline`, which is independently testable/benchmarkable
/// without any audio engine — this actor just owns capture + concurrency. On
/// platforms without live capture (headless CI), `start()` throws
/// `.captureUnavailable`; drive `PitchPipeline` directly there.
public actor TunerEngine {

    // MARK: Configuration

    /// Reference pitch, 430…450 Hz (default 440). Use `setA4` to change live.
    public private(set) var a4: Double
    /// Input source preference (auto / DI / mic).
    public private(set) var inputPreference: InputPreference
    /// Fundamental-tracking algorithm (benchmark-selected default).
    public private(set) var method: DetectionMethod
    /// Optional string-lock hint; `nil` = chromatic.
    public private(set) var targetNote: Note?

    // MARK: Output

    /// The live stream of readings. Each access mints an **independent** stream,
    /// so a consumer task being cancelled (e.g. the app's stop button tearing
    /// down its `for await` loop) only ends *that* stream — the engine keeps
    /// emitting to everyone else, and a later `start()` + fresh `readings`
    /// resumes cleanly. (A single shared `AsyncStream` is finished forever the
    /// first time its consumer is cancelled.)
    public var readings: AsyncStream<PitchReading> {
        AsyncStream(PitchReading.self, bufferingPolicy: .bufferingNewest(8)) { cont in
            let id = UUID()
            continuations[id] = cont
            cont.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private var continuations: [UUID: AsyncStream<PitchReading>.Continuation] = [:]

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    // MARK: State

    private let ring = SampleRingBuffer(capacity: 1 << 15)   // ~0.68 s at 48 kHz
    private var pipeline: PitchPipeline?
    private var consumer: Task<Void, Never>?
    private var isRunning = false
    private var calibration: ClockCalibration?

    #if canImport(AVFoundation)
    private var capture: AudioCapture?
    #endif

    // MARK: - Clock calibration

    /// Correction factor for the device's sample-clock error. 1.0 before convergence
    /// (≥30 s of listening). Apply: `trueHz = nominalHz * correctionFactor`.
    public var correctionFactor: Double { calibration?.correctionFactor ?? 1.0 }

    /// True once ~30 s of samples have been counted and the ppm estimate has converged.
    public var isClockCalibrated: Bool { calibration?.isConverged ?? false }

    /// Absolute pitch accuracy this device achieves in the current calibration state.
    public var absoluteAccuracyCents: Double { calibration?.absoluteAccuracyCents ?? (100.0 / 577.8) }

    public init(
        a4: Double = Pitch.standardA4,
        inputPreference: InputPreference = .auto,
        method: DetectionMethod = .mpm,
        targetNote: Note? = nil
    ) {
        self.a4 = min(Pitch.maxA4, max(Pitch.minA4, a4))
        self.inputPreference = inputPreference
        self.method = method
        self.targetNote = targetNote
    }

    // MARK: Lifecycle

    /// Request mic permission, start capture, and begin emitting readings.
    public func start() async throws {
        guard !isRunning else { return }

        #if canImport(AVFoundation)
        guard await MicrophonePermission.request() else {
            throw TunerEngineError.microphonePermissionDenied
        }

        let capture = AudioCapture(ring: ring)
        do {
            try capture.start(preference: inputPreference)
        } catch let error as TunerEngineError {
            throw error
        } catch {
            throw TunerEngineError.engineStartFailed(error.localizedDescription)
        }
        self.capture = capture

        let cal = ClockCalibration(nominalRate: capture.sampleRate)
        capture.calibration = cal
        cal.startMeasurement(wallTime: ProcessInfo.processInfo.systemUptime)
        calibration = cal

        let pipeline = PitchPipeline(
            sampleRate: capture.sampleRate, a4: a4, method: method, targetNote: targetNote
        )
        self.pipeline = pipeline
        isRunning = true
        consumer = Task { [weak self] in await self?.consume() }
        #else
        throw TunerEngineError.captureUnavailable
        #endif
    }

    /// Stop capture and analysis. The stream stays open (start again to resume).
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        consumer?.cancel()
        consumer = nil
        #if canImport(AVFoundation)
        capture?.calibration = nil
        capture?.stop()
        capture = nil
        #endif
        calibration = nil
        pipeline?.reset()
        ring.reset()
    }

    // MARK: Live setters (actors can't be set cross-isolation; use these)

    public func setA4(_ value: Double) {
        a4 = min(Pitch.maxA4, max(Pitch.minA4, value))
        pipeline?.a4 = a4
    }

    public func setInputPreference(_ value: InputPreference) { inputPreference = value }

    public func setMethod(_ value: DetectionMethod) {
        method = value
        pipeline?.method = value
    }

    public func setTargetNote(_ value: Note?) {
        targetNote = value
        pipeline?.targetNote = value
    }

    // MARK: Consumer loop (off the audio thread)

    /// Drain the ring and run the pipeline at a steady cadence. `Task.sleep`
    /// suspends actor isolation between passes, so the live setters interleave.
    private func consume() async {
        while isRunning, !Task.isCancelled {
            if let pipeline {
                let samples = ring.read()
                if !samples.isEmpty {
                    for reading in pipeline.process(samples) {
                        for cont in continuations.values { cont.yield(reading) }
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 4_000_000)   // ~4 ms
        }
    }
}
