import Foundation

/// A tiny, pure, **phase-continuous** additive tone synthesizer — the DSP core of
/// the reference-tone generator (DESIGN §2.7 / EXPERIENCE §3). It is *output*, kept
/// deliberately separate from the analysis pipeline: no audio engine, no capture,
/// just sample generation. That keeps it unit-testable headlessly (CI exercises it
/// like the rest of the DSP) while the app layer wraps it in an `AVAudioSourceNode`.
///
/// Design choices that make it pleasant and click-free:
/// - **Harmonic richness, not a harsh sine.** A gentle partial stack (organ-ish),
///   normalized by the sum of amplitudes so the summed sinusoids never clip.
/// - **Glided gain.** The output level eases toward `targetGain` over a short time
///   constant, so toggling on/off never pops.
/// - **Continuous phase.** The fundamental phase is preserved across `render` calls
///   *and across frequency changes*, so retuning to a new string never clicks.
///
/// The frequency comes from `Note.frequency(a4:)`, so the tone tracks the shared A4
/// calibration automatically.
public struct ToneSynth: Sendable {
    /// Output sample rate (Hz).
    public let sampleRate: Double
    /// Relative amplitudes of partials 1, 2, 3, … (index 0 is the fundamental).
    public var harmonics: [Double]
    /// Target fundamental in Hz (set from the active string at the current A4).
    public var frequency: Double
    /// Target output level 0…1; the rendered gain eases toward it.
    public var targetGain: Double
    /// Gain-glide time constant in seconds — the click-free attack/release.
    public var attackTime: Double

    private var phase: Double = 0      // fundamental cycle position, 0…1
    private var gain: Double = 0       // smoothed output gain

    /// A soft, slightly-rich default partial stack (a touch of harmonic colour).
    public static let defaultHarmonics: [Double] = [1.0, 0.5, 0.28, 0.14, 0.06]

    public init(
        sampleRate: Double = 48_000,
        harmonics: [Double] = ToneSynth.defaultHarmonics,
        frequency: Double = 440,
        targetGain: Double = 0,
        attackTime: Double = 0.012
    ) {
        self.sampleRate = sampleRate
        self.harmonics = harmonics
        self.frequency = frequency
        self.targetGain = targetGain
        self.attackTime = attackTime
    }

    /// The current (eased) gain — exposed for host fade bookkeeping and tests.
    public var currentGain: Double { gain }

    /// Render `buffer.count` mono samples in place, advancing phase + gain.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        let sum = harmonics.reduce(0, +)
        let scale = sum > 0 ? 1 / sum : 0
        let inc = sampleRate > 0 ? frequency / sampleRate : 0
        // Exponential one-pole glide toward the target gain.
        let glide = min(1, max(0, 1 - exp(-1 / max(1e-6, attackTime * sampleRate))))
        let twoPi = 2.0 * Double.pi

        for i in 0..<buffer.count {
            gain += (targetGain - gain) * glide
            if targetGain == 0 && gain < 1e-7 { gain = 0 }

            var s = 0.0
            if gain > 0 {
                for (k, amp) in harmonics.enumerated() where amp != 0 {
                    s += amp * sin(twoPi * Double(k + 1) * phase)
                }
            }
            buffer[i] = Float(s * scale * gain)

            phase += inc
            if phase >= 1 { phase -= floor(phase) }
        }
    }

    /// Array convenience over the pointer renderer (used by tests and offline use).
    public mutating func render(into array: inout [Float]) {
        array.withUnsafeMutableBufferPointer { render(into: $0) }
    }
}
