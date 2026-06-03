import SwiftUI

/// The hero note: a huge display letter, a smaller accidental, and a small mono
/// octave. Locks to sacred mint with a text bloom when in tune; dims to 0.32 in
/// the idle state. Mirrors `.note` / `NoteReadout` in the export.
public struct NoteReadout: View {
    let note: String
    let octave: Int
    var locked: Bool
    var dimmed: Bool

    public init(note: String, octave: Int, locked: Bool = false, dimmed: Bool = false) {
        self.note = note
        self.octave = octave
        self.locked = locked
        self.dimmed = dimmed
    }

    private var parts: (letter: String, accidental: String) { LumaMusic.parts(note) }

    public var body: some View {
        Group {
            if locked {
                stack.bloom(.text)
            } else {
                stack
            }
        }
        .opacity(dimmed ? 0.32 : 1)
        .lumaGlow(.lumaInTune)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note) \(octave)\(locked ? ", in tune" : "")")
    }

    private var stack: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(parts.letter)
                .font(.lumaNote)
                .tracking(-3)
            if !parts.accidental.isEmpty {
                Text(parts.accidental)
                    .font(LumaFont.display(LumaFont.Size.note * 0.34))
                    .foregroundStyle(locked ? Color.lumaInTune : Color.lumaDim)
                    .padding(.top, LumaFont.Size.note * 0.10)
            }
            Text("\(octave)")
                .font(LumaFont.mono(16))
                .lumaTracking(0.1, size: 16)
                .foregroundStyle(Color.lumaDim)
                .padding(.top, LumaFont.Size.note * 0.42)
                .padding(.leading, 6)
        }
        .foregroundStyle(locked ? Color.lumaInTune : Color.lumaInk)
        .animation(.easeInOut(duration: 0.36), value: locked)
    }
}

#if DEBUG
private struct NoteReadoutGallery: View {
    var body: some View {
        VStack(spacing: 40) {
            NoteReadout(note: "A\u{266F}", octave: 2)
            NoteReadout(note: "E", octave: 4, locked: true)
            NoteReadout(note: "D", octave: 3, dimmed: true)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.lumaBg)
    }
}

#Preview("Note — dark") { NoteReadoutGallery().preferredColorScheme(.dark) }
#Preview("Note — light") { NoteReadoutGallery().preferredColorScheme(.light) }
#endif
