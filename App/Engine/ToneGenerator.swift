import Foundation
import TunerEngine

#if canImport(AVFoundation)
import AVFoundation
#endif

/// On-device reference-tone player (DESIGN §2.7). It wraps the engine's pure
/// `ToneSynth` in an `AVAudioSourceNode` for **output only** — a path entirely
/// separate from capture/analysis, and (like everything in LUMA) with no
/// networking. Toggle with `setActive`, follow the selected string with
/// `setFrequency`; the synth's glided gain + continuous phase keep it click-free.
@MainActor
final class ToneGenerator {
    /// Output level when sounding (kept modest — it's a reference, not a lead).
    private let level = 0.22

    #if canImport(AVFoundation)
    private let engine = AVAudioEngine()
    private let renderer: ToneRenderer
    private let pinger: PingRenderer
    private let sampleRate: Double = 48_000
    private var sourceNode: AVAudioSourceNode?
    private var pingNode: AVAudioSourceNode?
    private var started = false
    #endif

    init() {
        #if canImport(AVFoundation)
        renderer = ToneRenderer(synth: ToneSynth(sampleRate: 48_000))
        pinger = PingRenderer(sampleRate: 48_000)
        #endif
    }

    /// Pre-warm the output engine so the first `ping` or `setActive` call does not
    /// trigger a lazy `AVAudioSession.setCategory` change while capture is live.
    /// Call this before `TunerEngine.start()`.
    func prepare() {
        #if canImport(AVFoundation)
        start()
        #endif
    }

    /// Sound (or silence) the tone at `frequency` Hz.
    func setActive(_ active: Bool, frequency: Double) {
        #if canImport(AVFoundation)
        renderer.update(frequency: frequency, gain: active ? level : 0)
        if active { start() }
        #endif
    }

    /// Retune the playing tone (follows the active string / A4 changes).
    func setFrequency(_ frequency: Double) {
        #if canImport(AVFoundation)
        renderer.update(frequency: frequency, gain: nil)
        #endif
    }

    /// Play a brief confirmation ping at `frequency` Hz on the lock rising edge.
    func ping(frequency: Double) {
        #if canImport(AVFoundation)
        pinger.trigger(frequency: frequency)
        start()
        #endif
    }

    /// Fully tear down the output engine.
    func stop() {
        #if canImport(AVFoundation)
        renderer.update(frequency: nil, gain: 0)
        engine.stop()
        started = false
        #endif
    }

    #if canImport(AVFoundation)
    private func start() {
        guard !started, let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        let node = AVAudioSourceNode(format: format) { [renderer] _, _, frameCount, ablPtr in
            renderer.render(frameCount: Int(frameCount), into: ablPtr)
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        let ping = AVAudioSourceNode(format: format) { [pinger] _, _, frameCount, ablPtr in
            pinger.render(frameCount: Int(frameCount), into: ablPtr)
            return noErr
        }
        pingNode = ping
        engine.attach(ping)
        engine.connect(ping, to: engine.mainMixerNode, format: format)

        #if os(iOS)
        // Play alongside live capture: a play-and-record session in measurement mode
        // keeps the analysis path AGC-free while still routing the tone out. Best
        // effort — the tone is a convenience and never essential.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement,
                                 options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try? session.setActive(true)
        #endif

        engine.prepare()
        do { try engine.start(); started = true } catch { started = false }
    }
    #endif
}

#if canImport(AVFoundation)
/// Thread bridge between the main-actor controls and the realtime render callback.
/// The `ToneSynth` lives here and is only mutated on the audio thread; parameter
/// changes arrive under a lock (mirrors `AudioCapture`'s `@unchecked Sendable`).
private final class ToneRenderer: @unchecked Sendable {
    private var synth: ToneSynth
    private let lock = NSLock()
    private var pendingFrequency: Double
    private var pendingGain: Double = 0

    init(synth: ToneSynth) {
        self.synth = synth
        self.pendingFrequency = synth.frequency
    }

    /// Update the target frequency and/or gain (control-rate, off the audio thread).
    func update(frequency: Double?, gain: Double?) {
        lock.lock()
        if let frequency, frequency > 0 { pendingFrequency = frequency }
        if let gain { pendingGain = gain }
        lock.unlock()
    }

    /// Realtime: fill the buffer list with `frameCount` mono samples.
    func render(frameCount: Int, into ablPtr: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock(); let f = pendingFrequency; let g = pendingGain; lock.unlock()
        synth.frequency = f
        synth.targetGain = g

        let buffers = UnsafeMutableAudioBufferListPointer(ablPtr)
        guard let first = buffers.first, let base = first.mData else { return }
        let ptr = base.assumingMemoryBound(to: Float.self)
        synth.render(into: UnsafeMutableBufferPointer(start: ptr, count: frameCount))

        // Duplicate to any additional channels the graph hands us (mono source).
        for i in 1..<buffers.count where buffers[i].mData != nil {
            buffers[i].mData!.assumingMemoryBound(to: Float.self).update(from: ptr, count: frameCount)
        }
    }
}

/// Single-shot confirmation tone: fast attack, ~300 ms hold, then glides to silence.
/// Triggered from the main actor; rendered on the audio thread under an NSLock.
private final class PingRenderer: @unchecked Sendable {
    private var synth: ToneSynth
    private let lock = NSLock()
    private var pendingFrequency: Double = 440
    private var pendingGain: Double = 0
    private var holdFramesLeft: Int = 0
    private let holdFrames: Int = Int(0.3 * 48_000)
    private let level: Double = 0.28

    init(sampleRate: Double) {
        synth = ToneSynth(sampleRate: sampleRate, attackTime: 0.012)
    }

    func trigger(frequency: Double) {
        lock.lock()
        pendingFrequency = frequency
        pendingGain = level
        holdFramesLeft = holdFrames
        lock.unlock()
    }

    func render(frameCount: Int, into ablPtr: UnsafeMutablePointer<AudioBufferList>) {
        lock.lock()
        if holdFramesLeft > 0 {
            holdFramesLeft -= frameCount
            if holdFramesLeft <= 0 { holdFramesLeft = 0; pendingGain = 0 }
        }
        let f = pendingFrequency
        let g = pendingGain
        lock.unlock()

        synth.frequency = f
        synth.targetGain = g

        let buffers = UnsafeMutableAudioBufferListPointer(ablPtr)
        guard let first = buffers.first, let base = first.mData else { return }
        let ptr = base.assumingMemoryBound(to: Float.self)
        synth.render(into: UnsafeMutableBufferPointer(start: ptr, count: frameCount))

        for i in 1..<buffers.count where buffers[i].mData != nil {
            buffers[i].mData!.assumingMemoryBound(to: Float.self).update(from: ptr, count: frameCount)
        }
    }
}
#endif
