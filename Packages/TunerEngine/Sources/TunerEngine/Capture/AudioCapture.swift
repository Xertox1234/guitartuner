import Foundation

#if canImport(AVFoundation)
import AVFoundation

/// Live capture via `AVAudioEngine`: mono, the hardware's native rate (we ask for
/// 48 kHz), small buffers. The tap is the **only** real-time code — it downmixes
/// to mono and writes into the lock-safe ring; every bit of analysis happens off
/// the audio thread on the consumer side (Plan 01 §2).
///
/// Input selection prefers a wired DI / interface (a clean direct signal is what
/// makes "strobe-grade" reachable, DESIGN §3); the built-in mic is the fallback.
/// This path is compiled on every platform but can only be *run* on-device — CI
/// exercises the pipeline through synthesized / file input instead.
final class AudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let ring: SampleRingBuffer
    private var running = false
    private var scratch = [Float]()

    /// The actual capture sample rate, known once started.
    private(set) var sampleRate: Double = 48_000

    init(ring: SampleRingBuffer) {
        self.ring = ring
    }

    /// Configure the session/input and start the tap. Throws if the engine or
    /// session won't start. Assumes record permission is already granted.
    func start(preference: InputPreference, preferredBufferFrames: AVAudioFrameCount = 2048) throws {
        guard !running else { return }

        #if os(iOS)
        try configureSession(preference: preference)
        #endif

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        sampleRate = format.sampleRate > 0 ? format.sampleRate : 48_000

        // Tap in the input's own format; downmix to mono ourselves (cheap, RT-safe).
        input.installTap(onBus: 0, bufferSize: preferredBufferFrames, format: format) { [weak self] buffer, _ in
            self?.ingest(buffer)
        }

        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Real-time tap

    /// Downmix to mono and hand the samples to the ring. No allocation in steady
    /// state (the scratch buffer is reused).
    private func ingest(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)

        if scratch.count < frames { scratch = [Float](repeating: 0, count: frames) }
        scratch.withUnsafeMutableBufferPointer { out in
            if channelCount == 1 {
                out.baseAddress!.update(from: channels[0], count: frames)
            } else {
                let scale = 1 / Float(channelCount)
                for i in 0..<frames {
                    var sum: Float = 0
                    for c in 0..<channelCount { sum += channels[c][i] }
                    out[i] = sum * scale
                }
            }
            ring.write(UnsafeBufferPointer(rebasing: out[0..<frames]))
        }
    }

    // MARK: - iOS session

    #if os(iOS)
    private func configureSession(preference: InputPreference) throws {
        let session = AVAudioSession.sharedInstance()
        // `.measurement` disables AGC / signal processing for a clean analysis path.
        // `.playAndRecord` is used even when the tone is off so the session is
        // already output-capable when the confirmation ping or reference tone starts —
        // avoids a live category change that would interrupt the capture tap on iOS.
        try session.setCategory(.playAndRecord, mode: .measurement,
                                options: [.allowBluetooth, .defaultToSpeaker])
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true)

        // Prefer a wired DI / interface unless the user forced the mic.
        if preference != .mic, let inputs = session.availableInputs {
            let preferred = inputs.first { Self.isExternalInput($0.portType) }
            if let preferred {
                try? session.setPreferredInput(preferred)
            } else if preference == .di {
                // .di explicitly requested but nothing external is connected.
                throw TunerEngineError.noDirectInput
            }
        }
    }

    /// Wired DI / interface ports we treat as "direct input."
    private static func isExternalInput(_ port: AVAudioSession.Port) -> Bool {
        switch port {
        case .usbAudio, .lineIn, .carAudio:
            return true
        default:
            return false
        }
    }
    #endif
}
#endif
