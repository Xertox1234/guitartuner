import Foundation

/// Minimal pitch helpers needed to *render* the UI — note naming, equal-tempered
/// frequency, and the lock window. This is data, not the tuner engine: no audio,
/// no DSP. Mirrors `Music` in `docs/design_reference/strobe-core.jsx`.
public enum LumaMusic {

    /// Chromatic note names with sharps (♯ = U+266F).
    public static let names: [String] = [
        "C", "C\u{266F}", "D", "D\u{266F}", "E", "F",
        "F\u{266F}", "G", "G\u{266F}", "A", "A\u{266F}", "B"
    ]

    /// |cents| under this = locked / in-tune (the sacred state).
    public static let lockCents: Double = 3.0
    /// Full-scale error window.
    public static let trackCents: Double = 50.0

    /// MIDI note → frequency at a given A4 reference.
    public static func frequency(midi: Int, a4: Double = 440) -> Double {
        a4 * pow(2, (Double(midi) - 69) / 12)
    }

    public struct Nearest: Equatable, Sendable {
        public let name: String
        public let octave: Int
        public let cents: Int
        public let midi: Int
    }

    /// Frequency → nearest note + signed cents offset.
    public static func nearest(frequency: Double, a4: Double = 440) -> Nearest {
        let midiFloat = 69 + 12 * log2(frequency / a4)
        let midi = Int(midiFloat.rounded())
        let cents = Int(((midiFloat - Double(midi)) * 100).rounded())
        let name = names[((midi % 12) + 12) % 12]
        let octave = Int((Double(midi) / 12).rounded(.down)) - 1
        return Nearest(name: name, octave: octave, cents: cents, midi: midi)
    }

    /// Split a note label like `"C♯"` into letter + accidental.
    public static func parts(_ name: String) -> (letter: String, accidental: String) {
        guard let first = name.first else { return ("", "") }
        return (String(first), String(name.dropFirst()))
    }
}
