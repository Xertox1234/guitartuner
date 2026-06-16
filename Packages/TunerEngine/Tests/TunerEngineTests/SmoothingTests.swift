import Testing
@testable import TunerEngine

@Suite struct SmoothingTests {

    @Test func constantInputIsPreserved() {
        var s = FrequencySmoother()
        var out = 0.0
        for _ in 0..<10 { out = s.update(frequency: 220, a4: 440) }
        #expect(abs(out - 220) < 0.5)
    }

    @Test func singleOctaveOutlierRejected() {
        var s = FrequencySmoother()
        for _ in 0..<5 { _ = s.update(frequency: 220, a4: 440) }
        let out = s.update(frequency: 440, a4: 440)   // lone octave spike
        #expect(abs(out - 220) < 5)                    // median rejects it
    }

    @Test func noteChangeConverges() {
        var s = FrequencySmoother()
        for _ in 0..<6 { _ = s.update(frequency: 220, a4: 440) }
        var out = 0.0
        for _ in 0..<6 { out = s.update(frequency: 330, a4: 440) }   // step to a new note
        #expect(abs(out - 330) < 2)
    }

    @Test func medianHelper() {
        #expect(FrequencySmoother.median([3, 1, 2]) == 2)
        #expect(FrequencySmoother.median([5]) == 5)
        #expect(FrequencySmoother.median([]) == 0)
    }

    // MARK: Sustain gate

    @Test func gateRequiresSustain() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        let a = gate.step(confidence: 0.9); #expect(a.emit);  #expect(!a.stable)
        let b = gate.step(confidence: 0.9); #expect(b.emit);  #expect(!b.stable)
        let c = gate.step(confidence: 0.9); #expect(c.emit);  #expect(c.stable)
    }

    @Test func gateRejectsLowConfidence() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        let a = gate.step(confidence: 0.3)
        #expect(!a.emit); #expect(!a.stable)
    }

    @Test func gateResetsStreakOnDropout() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        _ = gate.step(confidence: 0.9)
        _ = gate.step(confidence: 0.9)
        _ = gate.step(confidence: 0.1)               // dropout
        let after = gate.step(confidence: 0.9)
        #expect(after.emit)
        #expect(!after.stable)                       // streak restarted
    }
}
