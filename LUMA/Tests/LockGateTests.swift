import Foundation
import Testing
@testable import LUMA
import TunerEngine
import LumaDesignSystem

@Suite("LockGate")
struct LockGateTests {

    // Rising edge: first locked frame fires both haptic and ping.
    // Uses a non-distantPast `now` so the initial lastPingDate (.distantPast) is
    // far enough in the past to clear the cooldown check.
    @Test func risingEdgeFiresBoth() {
        var gate = LockGate()
        let result = gate.step(locked: true, now: Date(timeIntervalSinceReferenceDate: 1000))
        #expect(result.haptic == true)
        #expect(result.ping == true)
    }

    // Sustained lock: second consecutive locked frame fires nothing.
    @Test func sustainedLockIsQuiet() {
        var gate = LockGate()
        _ = gate.step(locked: true, now: .distantPast)
        let result = gate.step(locked: true, now: .distantPast)
        #expect(result.haptic == false)
        #expect(result.ping == false)
    }

    // Cooldown: lock within the cooldown window suppresses ping but still fires haptic.
    @Test func pingSuppressedWithinCooldown() {
        var gate = LockGate()
        gate.pingCooldown = 2.0
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = gate.step(locked: true,  now: t0)          // rising edge — ping fires
        _ = gate.step(locked: false, now: t0)          // fall
        let t1 = t0.addingTimeInterval(1.0)            // within cooldown
        let result = gate.step(locked: true, now: t1)  // rising edge again
        #expect(result.haptic == true)
        #expect(result.ping == false)
    }

    // Re-arm: lock after cooldown expires re-enables ping.
    @Test func pingReArmsAfterCooldown() {
        var gate = LockGate()
        gate.pingCooldown = 1.0
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = gate.step(locked: true,  now: t0)
        _ = gate.step(locked: false, now: t0)
        let t1 = t0.addingTimeInterval(1.5)            // past cooldown
        let result = gate.step(locked: true, now: t1)
        #expect(result.haptic == true)
        #expect(result.ping == true)
    }

    // reset(): clears edge state and cooldown so the very next lock fires both.
    @Test func resetClearsCooldownForImmediateReLock() {
        var gate = LockGate()
        gate.pingCooldown = 60.0
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        _ = gate.step(locked: true,  now: t0)
        _ = gate.step(locked: false, now: t0)
        gate.reset()
        let result = gate.step(locked: true, now: t0)  // still within cooldown, but reset
        #expect(result.haptic == true)
        #expect(result.ping == true)
    }
}

// Coupling guard (L4): PitchReading.lockCents and LumaMusic.lockCents must stay equal.
// The two packages can't share a constant (no cross-dep allowed), so this test is the
// only machine-checked link. If one changes without the other, CI fails here.
@Suite("LockCentsAlignment")
struct LockCentsAlignmentTests {
    @Test func lockCentsMatchAcrossPackages() {
        #expect(PitchReading.lockCents == LumaMusic.lockCents)
    }
}
