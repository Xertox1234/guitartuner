import Foundation
import Testing
@testable import TunerEngine

@Suite struct DetectionPolicyTests {

    @Test func fullRangeMatchesLegacyConstants() {
        let p = DetectionPolicy.fullRange
        #expect(p.searchRange == PitchPipeline.searchRange)          // 27...1400
        #expect(p.smoothingAlpha == AnalysisConfig.smoothingAlpha)   // 0.35
        #expect(p.smoothingMedianCount == AnalysisConfig.smoothingMedianCount)
        #expect(p.emitFloor == AnalysisConfig.emitFloor)             // 0.5
        #expect(p.bands.map(\.label) == ["high", "mid", "low", "ultralow"])
        #expect(p.bands[0].window == 1024 && p.bands[0].hop == 256)
        #expect(p.bands[3].window == 8192 && p.bands[3].hop == 2048)
    }

    @Test func searchRangesPerProfile() {
        #expect(DetectionPolicy.guitar.searchRange == 60...1400)
        #expect(DetectionPolicy.bass.searchRange == 25...420)
    }

    @Test func bandLookupByFrequency() {
        let p = DetectionPolicy.fullRange
        #expect(p.band(forFrequency: 300).label == "high")
        #expect(p.band(forFrequency: 150).label == "mid")
        #expect(p.band(forFrequency: 80).label == "low")
        #expect(p.band(forFrequency: 31).label == "ultralow")

        // Exact floor boundaries are inclusive of the higher band (>= semantics).
        #expect(p.band(forFrequency: 250).label == "high")
        #expect(p.band(forFrequency: 120).label == "mid")
        #expect(p.band(forFrequency: 40).label == "low")
    }

    @Test func confidenceFloorsMatchLegacySplit() {
        let p = DetectionPolicy.fullRange
        // Lock floor: 0.75 below 120 Hz, 0.90 at/above (former minLockConfidence).
        #expect(p.lockConfidence(forFrequency: 80) == 0.75)
        #expect(p.lockConfidence(forFrequency: 120) == 0.90)
        #expect(p.lockConfidence(forFrequency: 300) == 0.90)
        // Sustain floor: uniform 0.6 across all bands (former sustainMinConfidence).
        #expect(p.sustainConfidence(forFrequency: 31) == 0.6)
        #expect(p.sustainConfidence(forFrequency: 300) == 0.6)
    }

    @Test func bassUsesLongWindowDownTo40Hz() {
        let p = DetectionPolicy.bass
        #expect(p.band(forFrequency: 55).window == 8192, "A1 uses the long window")
        #expect(p.band(forFrequency: 41).window == 8192, "E1 uses the long window")
        #expect(p.acquire.window == 8192, "cold start is octave-safe")
        // Guitar is unchanged.
        #expect(DetectionPolicy.fullRange.band(forFrequency: 55).window == 4096)
    }

    @Test func bassLowensSustainFloorForWeakFundamentals() {
        let p = DetectionPolicy.bass
        // Bass low/ultralow sustain floor is relaxed below guitar's 0.6 so weak-fund
        // clarity dips don't shatter the lock streak.
        #expect(p.sustainConfidence(forFrequency: 41) < 0.6)
        #expect(p.sustainConfidence(forFrequency: 31) < 0.6)
        // Guitar floor is unchanged.
        #expect(DetectionPolicy.fullRange.sustainConfidence(forFrequency: 41) == 0.6)
    }

    @Test func engineStoresAndUpdatesPolicy() async {
        let engine = TunerEngine(detectionPolicy: .bass)
        #expect(await engine.detectionPolicy == .bass)
        await engine.setDetectionPolicy(.guitar)
        #expect(await engine.detectionPolicy == .guitar)
    }

}
