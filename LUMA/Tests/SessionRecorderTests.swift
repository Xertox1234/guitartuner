import Testing
import Foundation
import TunerEngine
@testable import LUMA

#if DEBUG
@MainActor
@Suite struct SessionRecorderTests {
    let fs = 48_000.0

    @Test func peakAndClipTracking() {
        let r = SessionRecorder(sampleRate: fs)
        r.append(samples: [0.2, -0.4, 0.9])
        #expect(abs(r.peak - 0.9) < 1e-6)
        #expect(r.clippedCount == 0)
        r.append(samples: [1.0, -1.2, 0.1])          // two |s| >= 1
        #expect(r.clippedCount == 2)
        #expect(abs(r.peak - 1.2) < 1e-6)
    }

    @Test func softCapTripsAndStopsAccumulating() {
        let r = SessionRecorder(sampleRate: 10, maxSeconds: 1)   // cap = 10 samples
        r.append(samples: Array(repeating: 0.1, count: 8))
        #expect(!r.capReached)
        r.append(samples: Array(repeating: 0.1, count: 8))
        #expect(r.capReached)
        #expect(r.samples.count == 10)
        r.append(samples: [0.1])                                 // no-op after cap
        #expect(r.samples.count == 10)
    }

    @Test func lockModeStemPrefillsFromTarget() {
        let stem = SessionRecorder.fixtureStem(targetNote: Note(midi: 40), a4: 440, override: nil)  // E2
        #expect(stem == "E2_82.41")
        #expect(Fixtures.parseTrueFrequency(fileName: stem! + ".wav", a4: 440) != nil)
    }

    @Test func autoModeRequiresExplicitValidLabel() {
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: nil) == nil)
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: "lowB_30.87") == "lowB_30.87")
        #expect(SessionRecorder.fixtureStem(targetNote: nil, a4: 440, override: "garbage!") == nil)
    }

    @Test func csvHasMetadataHeaderAndRawRows() {
        let r = SessionRecorder(sampleRate: fs)
        r.append(reading: PitchReading(frequency: 82.41, note: Note(midi: 40), cents: 0.3,
                                       confidence: 0.95, phase: 0.1, timestamp: 1.5))
        let meta = SessionMetadata(instrument: "guitar", tuningId: "std", a4: 440, correctionFactor: 1.0,
                                   sampleRate: fs, deviceModel: "test", referenceNote: "E2",
                                   capturedAt: Date(timeIntervalSince1970: 0), appVersion: "1.0.0")
        let csv = r.csv(metadata: meta)
        #expect(csv.contains("# a4,440.0"))
        #expect(csv.contains("timestamp,frequency,note,cents,confidence,phase,inharmonicityB,precisionCents,isLockIntegrated"))
        #expect(csv.contains("1.5,82.41,E2,0.3,0.95,0.1,,,false"))
    }
}
#endif
