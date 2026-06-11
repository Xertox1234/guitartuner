import SwiftUI

private struct LumaPaletteKey: EnvironmentKey {
    static let defaultValue: LumaPalette = .aurora
}

public extension EnvironmentValues {
    var lumaPalette: LumaPalette {
        get { self[LumaPaletteKey.self] }
        set { self[LumaPaletteKey.self] = newValue }
    }
}

public extension View {
    func lumaPalette(_ palette: LumaPalette) -> some View {
        environment(\.lumaPalette, palette)
    }
}
