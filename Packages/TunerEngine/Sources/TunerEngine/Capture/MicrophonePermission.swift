import Foundation

#if canImport(AVFoundation)
import AVFoundation
#endif

/// Microphone-permission gate for live capture. Audio is processed entirely
/// on-device and never recorded, stored, or transmitted (DESIGN §6) — the
/// usage-description copy says so.
enum MicrophonePermission {

    /// Request (or confirm) record permission. Returns `true` if granted.
    static func request() async -> Bool {
        #if os(iOS)
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
            }
        @unknown default:
            return false
        }
        #elseif os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }
}
