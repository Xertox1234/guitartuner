import Foundation

#if os(iOS)
import CoreHaptics
#endif

/// The in-tune confirmation tap (DESIGN §2.8 / EXPERIENCE §6) — a crisp Core
/// Haptics transient the moment the strobe locks. iOS/iPadOS only; a no-op
/// everywhere else, so callers stay platform-agnostic. The visual bloom is the
/// other half of the reward and is handled by the readouts. Reduce Motion governs
/// the strobe, not this — a user toggle (`hapticsEnabled`) controls the tap.
@MainActor
final class LockHaptics {
    #if os(iOS)
    private var engine: CHHapticEngine?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    #endif

    /// Warm up the engine ahead of the first lock so the tap has no latency.
    func prepare() {
        #if os(iOS)
        guard supported, engine == nil else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.resetHandler = { [weak self] in
            guard let self else { return }
            try? self.engine?.start()
        }
        try? engine?.start()
        #endif
    }

    /// One satisfying tap — the "earned" lock reward.
    func tap() {
        #if os(iOS)
        guard supported else { return }
        if engine == nil { prepare() }
        guard let engine else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            // Haptics are a non-essential flourish; never surface a failure.
        }
        #endif
    }

    func teardown() {
        #if os(iOS)
        engine?.stop()
        engine = nil
        #endif
    }
}
