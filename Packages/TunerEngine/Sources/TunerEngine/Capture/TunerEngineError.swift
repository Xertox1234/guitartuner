import Foundation

/// Errors the live engine can surface from `start()`. The DSP pipeline itself
/// never throws — it just consumes samples.
public enum TunerEngineError: Error, Equatable, Sendable {
    /// The user denied (or restricted) microphone access.
    case microphonePermissionDenied
    /// `.di` was forced but no wired DI / interface is connected.
    case noDirectInput
    /// Live capture isn't available on this platform (e.g. headless Linux CI).
    case captureUnavailable
    /// `AVAudioEngine` failed to start; `underlying` is its description.
    case engineStartFailed(String)
}

extension TunerEngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is off. LUMA analyses pitch entirely on-device — your playing is never recorded or sent."
        case .noDirectInput:
            return "No wired input/interface found. Connect a DI or choose the microphone."
        case .captureUnavailable:
            return "Live audio capture isn't available on this platform."
        case .engineStartFailed(let detail):
            return "Couldn't start audio: \(detail)"
        }
    }
}
