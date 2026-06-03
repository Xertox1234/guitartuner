import XCTest
@testable import TunerEngine

final class StrobePhaseTests: XCTestCase {
    let fs = 48_000.0

    private func raw(_ f: Double, _ count: Int) -> [Float] {
        Array(Synth.pure(frequency: f, sampleRate: fs, seconds: Double(count) / fs + 0.02).prefix(count))
    }
    /// Shortest signed distance between two wrapped phases, in (−0.5, 0.5].
    private func delta(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        d -= (d).rounded()
        return d
    }

    func testPhaseInUnitInterval() throws {
        let s = raw(330, 4096)
        let p = try XCTUnwrap(StrobePhase.phase(Array(s[0..<2048]), referenceFrequency: 330, sampleRate: fs, globalStart: 0))
        XCTAssertGreaterThanOrEqual(p, 0)
        XCTAssertLessThan(p, 1)
    }

    func testInTuneIsStationary() throws {
        // Signal exactly at the reference → phase must not move between hops.
        let fRef = 440.0
        let n = 2048, hop = 512
        let s = raw(fRef, n + hop)
        let p0 = try XCTUnwrap(StrobePhase.phase(Array(s[0..<n]), referenceFrequency: fRef, sampleRate: fs, globalStart: 0))
        let p1 = try XCTUnwrap(StrobePhase.phase(Array(s[hop..<hop + n]), referenceFrequency: fRef, sampleRate: fs, globalStart: hop))
        XCTAssertLessThan(abs(delta(p0, p1)), 0.015, "in-tune strobe should be frozen")
    }

    func testDetuneScrollsProportionallyAndSigned() throws {
        let fRef = 440.0
        let n = 2048, hop = 512
        let dt = Double(hop) / fs

        func scrollPerHop(cents: Double) throws -> Double {
            let f0 = fRef * pow(2, cents / 1200)
            let s = raw(f0, n + hop)
            let p0 = try XCTUnwrap(StrobePhase.phase(Array(s[0..<n]), referenceFrequency: fRef, sampleRate: fs, globalStart: 0))
            let p1 = try XCTUnwrap(StrobePhase.phase(Array(s[hop..<hop + n]), referenceFrequency: fRef, sampleRate: fs, globalStart: hop))
            return delta(p0, p1)
        }

        let sharp = try scrollPerHop(cents: 30)
        let flat = try scrollPerHop(cents: -30)

        // Opposite directions for sharp vs flat.
        XCTAssertGreaterThan(sharp * flat, -1)              // sanity
        XCTAssertEqual(sharp, -flat, accuracy: 0.01)        // symmetric
        XCTAssertNotEqual(sharp.sign, flat.sign)

        // Magnitude ≈ beat frequency × Δt (cycles).
        let expected = abs(fRef * pow(2, 30.0 / 1200) - fRef) * dt
        XCTAssertEqual(abs(sharp), expected, accuracy: 0.02)
    }

    func testRefineFrequencyImprovesEstimate() throws {
        let fTrue = 220.0
        let n = 2048, hop = 512
        let s = raw(fTrue, n + hop)
        let guess = fTrue * pow(2, 8.0 / 1200)              // 8¢ sharp guess
        let refined = StrobePhase.refineFrequency(
            current: Array(s[hop..<hop + n]), previous: Array(s[0..<n]),
            frequency: guess, sampleRate: fs, hop: hop
        )
        let guessErr = abs(TestSupport.cents(guess, fTrue))
        let refinedErr = abs(TestSupport.cents(refined, fTrue))
        XCTAssertLessThan(refinedErr, guessErr)
        XCTAssertLessThan(refinedErr, 1.5)                  // sub-cent-ish
    }

    func testRefineClampsRunawayCorrection() {
        // Frames that disagree wildly with the analysis frequency can't move us
        // more than the clamp (no octave jumps from phase noise).
        let n = 1024, hop = 256
        let a = raw(200, n)
        let b = raw(900, n)
        let refined = StrobePhase.refineFrequency(
            current: b, previous: a, frequency: 200, sampleRate: fs, hop: hop, maxCents: 35
        )
        XCTAssertLessThanOrEqual(abs(TestSupport.cents(refined, 200)), 35.001)
    }
}
