import Foundation

enum LumaConfig {
    // Safe: well-formed ASCII literal can never return nil from URL(string:).
    static let apiBaseURL = URL(string: "https://luma-api.william-tower.workers.dev").unsafelyUnwrapped
}
