import XCTest
@testable import TunerEngine

final class SmoothingTests: XCTestCase {

    func testConstantInputIsPreserved() {
        var s = FrequencySmoother()
        var out = 0.0
        for _ in 0..<10 { out = s.update(frequency: 220, a4: 440) }
        XCTAssertEqual(out, 220, accuracy: 0.5)
    }

    func testSingleOctaveOutlierRejected() {
        var s = FrequencySmoother()
        for _ in 0..<5 { _ = s.update(frequency: 220, a4: 440) }
        let out = s.update(frequency: 440, a4: 440)   // lone octave spike
        XCTAssertEqual(out, 220, accuracy: 5)          // median rejects it
    }

    func testNoteChangeConverges() {
        var s = FrequencySmoother()
        for _ in 0..<6 { _ = s.update(frequency: 220, a4: 440) }
        var out = 0.0
        for _ in 0..<6 { out = s.update(frequency: 330, a4: 440) }   // step to a new note
        XCTAssertEqual(out, 330, accuracy: 2)
    }

    func testMedianHelper() {
        XCTAssertEqual(FrequencySmoother.median([3, 1, 2]), 2)
        XCTAssertEqual(FrequencySmoother.median([5]), 5)
        XCTAssertEqual(FrequencySmoother.median([]), 0)
    }

    // MARK: Sustain gate

    func testGateRequiresSustain() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        let a = gate.step(confidence: 0.9); XCTAssertTrue(a.emit);  XCTAssertFalse(a.stable)
        let b = gate.step(confidence: 0.9); XCTAssertTrue(b.emit);  XCTAssertFalse(b.stable)
        let c = gate.step(confidence: 0.9); XCTAssertTrue(c.emit);  XCTAssertTrue(c.stable)
    }

    func testGateRejectsLowConfidence() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        let a = gate.step(confidence: 0.3)
        XCTAssertFalse(a.emit); XCTAssertFalse(a.stable)
    }

    func testGateResetsStreakOnDropout() {
        var gate = SustainGate(minConfidence: 0.7, sustainFrames: 3)
        _ = gate.step(confidence: 0.9)
        _ = gate.step(confidence: 0.9)
        _ = gate.step(confidence: 0.1)               // dropout
        let after = gate.step(confidence: 0.9)
        XCTAssertTrue(after.emit)
        XCTAssertFalse(after.stable)                 // streak restarted
    }
}
