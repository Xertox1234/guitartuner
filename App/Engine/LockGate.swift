import Foundation

// Rising-edge detector and confirmation-ping rate limiter for the in-tune lock event.
//
// Haptic feedback fires on every rising edge (fast, tactile).
// The audible ping is rate-limited: after one fires, a further lock within
// `pingCooldown` seconds is silenced. Cooldown resets on target change so
// switching strings and locking quickly still triggers a ping on the new string.
struct LockGate {
    private var wasLocked = false
    private var lastPingDate: Date = .distantPast
    var pingCooldown: TimeInterval = 1.5

    /// Advance one reading frame.
    /// - Returns: `(haptic: Bool, ping: Bool)` — whether each should fire this frame.
    mutating func step(locked: Bool, now: Date = Date()) -> (haptic: Bool, ping: Bool) {
        let risingEdge = locked && !wasLocked
        wasLocked = locked
        guard risingEdge else { return (false, false) }
        let pingAllowed = now.timeIntervalSince(lastPingDate) >= pingCooldown
        if pingAllowed { lastPingDate = now }
        return (true, pingAllowed)
    }

    /// Reset edge state and cooldown — call on target/string change so the first
    /// lock on the new string always triggers both haptic and ping.
    mutating func reset() {
        wasLocked = false
        lastPingDate = .distantPast
    }
}
