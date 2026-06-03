import Foundation

/// A named musical note (equal temperament). UI-free value type — the engine
/// emits these; the app maps them to whatever the design system needs.
///
/// `octave` is the scientific-pitch octave (A4 = MIDI 69 → octave 4, C4 = 60).
/// Names use sharps (♯ = U+266F), matching `LumaMusic.names` in the design
/// system so the app's note rendering lines up without a cross-dependency.
public struct Note: Sendable, Equatable, Hashable, CustomStringConvertible {
    public let midi: Int
    public let octave: Int
    public let name: String

    public init(midi: Int) {
        self.midi = midi
        self.name = Pitch.names[((midi % 12) + 12) % 12]
        self.octave = Int((Double(midi) / 12).rounded(.down)) - 1
    }

    /// e.g. `"C♯4"`, `"E2"`.
    public var description: String { "\(name)\(octave)" }

    /// The note's exact equal-tempered frequency at a given A4 reference.
    public func frequency(a4: Double = Pitch.standardA4) -> Double {
        Pitch.frequency(midi: midi, a4: a4)
    }
}

/// Pure pitch math: MIDI ⇄ frequency and frequency → (nearest note, signed
/// cents). No audio, no DSP — the conversions the readings are built from.
public enum Pitch {
    /// Chromatic note names with sharps (♯ = U+266F).
    public static let names: [String] = [
        "C", "C\u{266F}", "D", "D\u{266F}", "E", "F",
        "F\u{266F}", "G", "G\u{266F}", "A", "A\u{266F}", "B"
    ]

    /// Concert-pitch default; the engine's `a4` is adjustable 430…450.
    public static let standardA4: Double = 440
    public static let minA4: Double = 430
    public static let maxA4: Double = 450

    /// MIDI note → frequency at a given A4 reference.
    public static func frequency(midi: Double, a4: Double = standardA4) -> Double {
        a4 * pow(2, (midi - 69) / 12)
    }

    public static func frequency(midi: Int, a4: Double = standardA4) -> Double {
        frequency(midi: Double(midi), a4: a4)
    }

    /// Continuous MIDI value of a frequency (69.0 = A4). Undefined for f ≤ 0.
    public static func midi(frequency: Double, a4: Double = standardA4) -> Double {
        69 + 12 * log2(frequency / a4)
    }

    /// Frequency → nearest note plus the signed cents offset (−50…+50).
    /// Returns `nil` for non-positive frequencies.
    public static func nearest(frequency: Double, a4: Double = standardA4) -> (note: Note, cents: Double)? {
        guard frequency > 0 else { return nil }
        let midiFloat = midi(frequency: frequency, a4: a4)
        let nearestMidi = Int(midiFloat.rounded())
        let cents = (midiFloat - Double(nearestMidi)) * 100
        return (Note(midi: nearestMidi), cents)
    }
}
