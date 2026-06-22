import Testing
import Foundation
@testable import TunerEngine

/// The DEBUG-only raw-sample emission: gated by `setRecording`, lossless, and it
/// finishes cleanly so a draining `for await` ends (spec §4, §11).
@Suite struct RawSampleEmissionTests {

    @Test func gatedByRecordingFlagAndFinishesOnStop() async {
        let engine = TunerEngine()
        let stream = await engine.rawSamples            // registers the continuation now
        var received: [[Float]] = []
        let drain = Task { for await block in stream { received.append(block) } }

        await engine.emitRawForRecording([1, 2, 3])     // not recording → dropped
        await engine.setRecording(true)
        await engine.emitRawForRecording([4, 5, 6])
        await engine.emitRawForRecording([7, 8, 9])
        await engine.setRecording(false)                // finishes the stream
        await drain.value                               // ends because the stream finished

        #expect(received == [[4, 5, 6], [7, 8, 9]])
    }

    @Test func losslessUnderManyBlocks() async {
        let engine = TunerEngine()
        let stream = await engine.rawSamples
        var total = 0
        let drain = Task { for await block in stream { total += block.count } }
        await engine.setRecording(true)
        for _ in 0..<1000 { await engine.emitRawForRecording([0, 0, 0, 0]) }
        await engine.setRecording(false)
        await drain.value
        #expect(total == 4000)                          // no drops
    }
}
