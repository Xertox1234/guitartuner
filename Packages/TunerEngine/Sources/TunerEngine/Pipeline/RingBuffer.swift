import Foundation
import os

/// Single-producer / single-consumer sample ring for the real-time hand-off. The
/// audio tap (producer) only ever **copies samples in and bumps an index** — no
/// allocation, no analysis, bounded work — so it stays real-time safe; all DSP
/// runs on the consumer side off the audio thread (Plan 01 §2).
///
/// Synchronisation is an `OSAllocatedUnfairLock` held only around the index
/// arithmetic + a `memcpy`. It's bounded and allocation-free, and (unlike a
/// plain mutex) donates priority, so the audio thread can't be blocked by the
/// consumer for long. On overflow we drop the oldest samples rather than ever
/// blocking the producer.
final class SampleRingBuffer: @unchecked Sendable {
    private struct Indices: Sendable { var write = 0; var read = 0 }   // absolute, monotonic

    private let storage: UnsafeMutableBufferPointer<Float>
    private let capacity: Int
    private let state = OSAllocatedUnfairLock(initialState: Indices())

    init(capacity: Int) {
        // Round up to a power of two so wrap is a mask, not a modulo.
        var cap = 1
        while cap < max(capacity, 2) { cap <<= 1 }
        self.capacity = cap
        self.storage = .allocate(capacity: cap)
        self.storage.initialize(repeating: 0)
    }

    deinit {
        storage.deinitialize()
        storage.deallocate()
    }

    private var mask: Int { capacity - 1 }

    /// Producer side (audio thread). Copies `samples` in; if that would overrun
    /// the unread span, the oldest samples are dropped (never blocks).
    func write(_ samples: UnsafeBufferPointer<Float>) {
        let n = samples.count
        guard n > 0 else { return }
        state.withLockUnchecked { idx in
            // If the chunk is bigger than the whole ring, keep only the tail.
            let src = n <= capacity ? 0 : n - capacity
            let toCopy = n - src
            for i in 0..<toCopy {
                storage[(idx.write + i) & mask] = samples[src + i]
            }
            idx.write += toCopy
            // Overflow → advance read to keep exactly `capacity` samples behind.
            if idx.write - idx.read > capacity {
                idx.read = idx.write - capacity
            }
        }
    }

    /// Convenience for `[Float]` (tests / file feeds).
    func write(_ samples: [Float]) {
        samples.withUnsafeBufferPointer { write($0) }
    }

    /// Number of unread samples.
    var available: Int {
        state.withLockUnchecked { $0.write - $0.read }
    }

    /// Consumer side. Reads up to `maxCount` unread samples (all of them if
    /// `maxCount` is nil), advancing the read cursor.
    func read(upTo maxCount: Int? = nil) -> [Float] {
        state.withLockUnchecked { idx in
            let count = min(idx.write - idx.read, maxCount ?? Int.max)
            guard count > 0 else { return [] }
            var out = [Float](repeating: 0, count: count)
            for i in 0..<count {
                out[i] = storage[(idx.read + i) & mask]
            }
            idx.read += count
            return out
        }
    }

    func reset() {
        state.withLockUnchecked { $0 = Indices() }
    }
}
