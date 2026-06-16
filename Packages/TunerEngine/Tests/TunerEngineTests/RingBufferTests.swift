import Testing
@testable import TunerEngine

@Suite struct RingBufferTests {

    @Test func fifoOrder() {
        let ring = SampleRingBuffer(capacity: 16)
        ring.write([1, 2, 3, 4])
        #expect(ring.available == 4)
        #expect(ring.read() == [1, 2, 3, 4])
        #expect(ring.available == 0)
        #expect(ring.read() == [])
    }

    @Test func partialRead() {
        let ring = SampleRingBuffer(capacity: 16)
        ring.write([1, 2, 3, 4, 5])
        #expect(ring.read(upTo: 2) == [1, 2])
        #expect(ring.read(upTo: 2) == [3, 4])
        #expect(ring.read() == [5])
    }

    @Test func wrapAround() {
        let ring = SampleRingBuffer(capacity: 8)
        ring.write([1, 2, 3, 4, 5])
        #expect(ring.read() == [1, 2, 3, 4, 5])
        // Write across the physical wrap boundary.
        ring.write([6, 7, 8, 9])
        #expect(ring.read() == [6, 7, 8, 9])
    }

    @Test func overflowDropsOldest() {
        let ring = SampleRingBuffer(capacity: 8)
        ring.write(Array(1...12).map(Float.init))   // 12 > 8 → keep newest 8
        let out = ring.read()
        #expect(out.count == 8)
        #expect(out == Array(5...12).map(Float.init))
    }

    @Test func chunkLargerThanCapacity() {
        let ring = SampleRingBuffer(capacity: 4)
        ring.write(Array(1...10).map(Float.init))   // keep last 4
        #expect(ring.read() == [7, 8, 9, 10])
    }

    @Test func reset() {
        let ring = SampleRingBuffer(capacity: 8)
        ring.write([1, 2, 3])
        ring.reset()
        #expect(ring.available == 0)
        #expect(ring.read() == [])
    }
}
