import Foundation

/// Pure colour logic for the Metal hero path (`StrobeRenderer`), kept SwiftUI-free
/// and unit-tested like `StrobeMath`. Mirrors the per-frame colour blend in
/// `AuroraStrobe.draw` so the GPU path reads from the same palette as the Canvas.
enum StrobeShaderColors {
    /// The per-ribbon main colour: the active side (flat → blue, sharp → warm)
    /// blended toward the sacred mint by proximity + lock. Mirrors `col` in
    /// `AuroraStrobe`.
    static func main(cents: Double, prox: Double, lock: Double, pal: StrobePalette) -> RGB {
        let side = cents < 0 ? mix(pal.flat, pal.flat2, 0.35) : mix(pal.sharp, pal.sharp2, 0.35)
        return mix(side, pal.tune, max(prox * 0.7, lock))
    }

    /// The central-column colour: the main colour pulled the rest of the way to mint
    /// at lock. Mirrors `colCol` in `AuroraStrobe`.
    static func column(main: RGB, lock: Double, pal: StrobePalette) -> RGB {
        mix(main, pal.tune, lock)
    }
}

extension RGB {
    /// Packed for a Metal uniform (`float4`, alpha 1). `SIMD4` is in the standard
    /// library, so this stays available even where MetalKit isn't.
    var simd4: SIMD4<Float> { SIMD4<Float>(Float(r), Float(g), Float(b), 1) }
}
