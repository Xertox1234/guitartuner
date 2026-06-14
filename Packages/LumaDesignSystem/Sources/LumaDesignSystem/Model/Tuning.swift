import Foundation

/// One string of a tuning. `idx` numbers strings high→low in the conventional
/// sense (6 = lowest-pitched guitar string), but they render **left→right,
/// low→high**. Mirrors `TUNINGS` in `docs/design_reference/strobe-core.jsx`.
public struct GuitarString: Identifiable, Codable, Hashable, Sendable {
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
    /// Build a tuning from MIDI notes given **low → high**. String `idx` numbers
    /// high→low (lowest-pitched string gets the largest `idx`, matching the 6-=low-E
    /// convention), and each string's note name + octave derive from its MIDI value
    /// — so a preset is just *a set of target notes on the chromatic core*
    /// (DESIGN §2.5). Names use sharps, matching the rest of LUMA.
    public static func make(id: String, label: String, midis: [Int]) -> Tuning {
        let count = midis.count
        let strings = midis.enumerated().map { offset, midi in
            GuitarString(
                idx: count - offset,
                midi: midi,
                note: LumaMusic.noteName(midi: midi),
                octave: LumaMusic.octave(midi: midi)
            )
        }
        return Tuning(id: id, label: label, strings: strings)
    }

    /// E2 A2 D3 G3 B3 E4 — midi 40 45 50 55 59 64.
    public static let guitar = make(id: "guitar", label: "Standard", midis: [40, 45, 50, 55, 59, 64])

    /// E1 A1 D2 G2 — midi 28 33 38 43.
    public static let bass = make(id: "bass", label: "Standard", midis: [28, 33, 38, 43])

    /// Guitar presets (the v1 set), all built on the chromatic core.
    public static let guitarPresets: [Tuning] = [
        guitar,
        make(id: "guitar-drop-d", label: "Drop D",         midis: [38, 45, 50, 55, 59, 64]),
        make(id: "guitar-half",   label: "½-Step Down",     midis: [39, 44, 49, 54, 58, 63]),
        make(id: "guitar-full",   label: "Full-Step Down",  midis: [38, 43, 48, 53, 57, 62]),
        make(id: "guitar-drop-c", label: "Drop C",          midis: [36, 43, 48, 53, 57, 62]),
        make(id: "guitar-open-g", label: "Open G",          midis: [38, 43, 50, 55, 59, 62]),
        make(id: "guitar-dadgad", label: "DADGAD",          midis: [38, 45, 50, 55, 57, 62])
    ]

    /// Bass presets — 4- and 5-string variants (DESIGN §2.5).
    public static let bassPresets: [Tuning] = [
        bass,
        make(id: "bass-drop-d",   label: "Drop D",          midis: [26, 33, 38, 43]),
        make(id: "bass-half",     label: "½-Step Down",     midis: [27, 32, 37, 42]),
        make(id: "bass-5",        label: "5-String",        midis: [23, 28, 33, 38, 43]),
        make(id: "bass-5-drop-a", label: "5-String Drop A", midis: [21, 28, 33, 38, 43])
    ]

    public static func standard(for instrument: Instrument) -> Tuning {
        instrument == .guitar ? guitar : bass
    }

    /// The selectable preset list for an instrument (Standard first).
    public static func presets(for instrument: Instrument) -> [Tuning] {
        instrument == .guitar ? guitarPresets : bassPresets
    }
}
