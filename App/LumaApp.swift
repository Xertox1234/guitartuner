import SwiftUI
import LumaDesignSystem

@main
struct LumaApp: App {
    init() {
        // Register bundled Chakra Petch / JetBrains Mono if present;
        // otherwise LumaFont falls back to SF Pro Display / SF Mono.
        LumaFonts.registerIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 900)
        .windowResizability(.contentSize)
        #endif
    }
}
