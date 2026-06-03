import XCTest
@testable import TunerEngine

final class RingBufferTests: XCTestCase {

    func testFIFOOrder() {
        let ring = SampleRingBuffer(capacity: 16)
        ring.write([1, 2, 3, 4])
        XCTAssertEqual(ring.available, 4)
        XCTAssertEqual(ring.read(), [1, 2, 3, 4])
        XCTAssertEqual(ring.available, 0)
        XCTAssertEqual(ring.read(), [])
    }

    func testPartialRead() {
        let ring = SampleRingBuffer(capacity: 16)
        ring.write([1, 2, 3, 4, 5])
        XCTAssertEqual(ring.read(upTo: 2), [1, 2])
        XCTAssertEqual(ring.read(upTo: 2), [3, 4])
        XCTAssertEqual(ring.read(), [5])
    }

    func testWrapAround() {
        let ring = SampleRingBuffer(capacity: 8)   // rounds up to 8
        ring.write([1, 2, 3, 4, 5])
        XCTAssertEqual(ring.read(), [1, 2, 3, 4, 5])
        // Now write across the physical wrap boundary.
        ring.write([6, 7, 8, 9])
        XCTAssertEqual(ring.read(), [6, 7, 8, 9])
    }

    func testOverflowDropsOldest() {
        let ring = SampleRingBuffer(capacity: 8)    // capacity 8
        ring.write(Array(1...12).map(Float.init))   // 12 > 8 → keep newest 8
        let out = ring.read()
        XCTAssertEqual(out.count, 8)
        XCTAssertEqual(out, Array(5...12).map(Float.init))
    }

    func testChunkLargerThanCapacity() {
        let ring = SampleRingBuffer(capacity: 4)
        ring.write(Array(1...10).map(Float.init))   // keep last 4
        XCTAssertEqual(ring.read(), [7, 8, 9, 10])
    }

    func testReset() {
        let ring = SampleRingBuffer(capacity: 8)
        ring.write([1, 2, 3])
        ring.reset()
        XCTAssertEqual(ring.available, 0)
        XCTAssertEqual(ring.read(), [])
    }
}
