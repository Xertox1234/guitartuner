import Foundation

/// One string of a tuning. `idx` numbers strings high→low in the conventional
/// sense (6 = lowest-pitched guitar string), but they render **left→right,
/// low→high**. Mirrors `TUNINGS` in `docs/design_reference/strobe-core.jsx`.
public struct GuitarString: Identifiable, Hashable, Sendable {
    public let idx: Int
    public let midi: Int
    public let note: String
    public let octave: Int

    public var id: Int { idx }

    public init(idx: Int, midi: Int, note: String, octave: Int) {
        self.idx = idx
        self.midi = midi
        self.note = note
        self.octave = octave
    }
}

public struct Tuning: Identifiable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let strings: [GuitarString]

    public init(id: String, label: String, strings: [GuitarString]) {
        self.id = id
        self.label = label
        self.strings = strings
    }
}

public enum Instrument: String, CaseIterable, Identifiable, Sendable {
    case guitar, bass
    public var id: String { rawValue }
}

public enum Tunings {
    /// E2 A2 D3 G3 B3 E4 — midi 40 45 50 55 59 64.
    public static let guitar = Tuning(id: "guitar", label: "Guitar", strings: [
        GuitarString(idx: 6, midi: 40, note: "E", octave: 2),
        GuitarString(idx: 5, midi: 45, note: "A", octave: 2),
        GuitarString(idx: 4, midi: 50, note: "D", octave: 3),
        GuitarString(idx: 3, midi: 55, note: "G", octave: 3),
        GuitarString(idx: 2, midi: 59, note: "B", octave: 3),
        GuitarString(idx: 1, midi: 64, note: "E", octave: 4)
    ])

    /// E1 A1 D2 G2 — midi 28 33 38 43.
    public static let bass = Tuning(id: "bass", label: "Bass", strings: [
        GuitarString(idx: 4, midi: 28, note: "E", octave: 1),
        GuitarString(idx: 3, midi: 33, note: "A", octave: 1),
        GuitarString(idx: 2, midi: 38, note: "D", octave: 2),
        GuitarString(idx: 1, midi: 43, note: "G", octave: 2)
    ])

    public static func standard(for instrument: Instrument) -> Tuning {
        instrument == .guitar ? guitar : bass
    }
}
