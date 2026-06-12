import SwiftUI
import LumaDesignSystem

@main
struct LumaApp: App {
    /// The single live tuner — one engine, one mic — shared by the main window and
    /// the macOS menu-bar micro-strobe (EXPERIENCE §8: *same DSP, same look*).
    @State private var model = LiveTunerModel()

    init() {
        // Register bundled Chakra Petch / JetBrains Mono if present;
        // otherwise LumaFont falls back to SF Pro Display / SF Mono.
        LumaFonts.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 720)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        // A tiny live ring for quick checks while recording, reusing the same model.
        MenuBarExtra {
            MenuBarTuner(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
