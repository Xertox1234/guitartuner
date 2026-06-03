import SwiftUI

/// The metadata line under the note: `<Hz> · <ALGO> · <rate>` in tabular mono,
/// e.g. `146.8 Hz · YIN · 48k`. The number reads `dim`, the rest `faint`.
/// Mirrors `.freq-line` / `FreqLine` in the export.
public struct FreqLine: View {
    let freq: Double
    var algo: String
    var rate: String

    public init(freq: Double, algo: String = "YIN", rate: String = "48k") {
        self.freq = freq
        self.algo = algo
        self.rate = rate
    }

    public var body: some View {
        (
            Text(String(format: "%.1f", freq)).foregroundStyle(Color.lumaDim)
            + Text(" Hz \u{00B7} \(algo) \u{00B7} \(rate)").foregroundStyle(Color.lumaFaint)
        )
        .font(.lumaMicroMono)
        .lumaTracking(Tracking.chipWide, size: LumaFont.Size.micro)
        .accessibilityLabel("\(String(format: "%.1f", freq)) hertz, \(algo), \(rate)")
    }
}

#if DEBUG
#Preview("Freq line — dark") {
    VStack(spacing: 12) {
        FreqLine(freq: 146.8)
        FreqLine(freq: 110.0, algo: "TONE", rate: "sine")
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.lumaBg)
    .preferredColorScheme(.dark)
}
#endif
