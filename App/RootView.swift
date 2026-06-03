import SwiftUI
import LumaDesignSystem

/// Manual theme override (dark-first; the system option follows the OS).
enum LumaTheme: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

/// Root of the app. The **Tuner** tab now runs the live `TunerEngine` (Plan 01);
/// the **Strobe** tab keeps the interactive simulator lab (Plan 03); plus the
/// Design-System Gallery, with a manual theme toggle.
struct RootView: View {
    /// The shared live tuner, owned by `LumaApp` (also drives the menu-bar strobe).
    var model: LiveTunerModel
    @AppStorage("theme") private var themeRaw = LumaTheme.dark.rawValue
    private var theme: LumaTheme { LumaTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        TabView {
            LiveTunerScreen(model: model)
                .tabItem { Label("Tuner", systemImage: "tuningfork") }

            StrobeLab()
                .tabItem { Label("Strobe", systemImage: "waveform") }

            NavigationStack {
                DesignSystemGallery()
                    .navigationTitle("Design System")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar { themeMenu }
            }
            .tabItem { Label("Design", systemImage: "paintpalette") }
        }
        .tint(.lumaInTune)
        .preferredColorScheme(theme.colorScheme)
    }

    private var themeMenu: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Theme", selection: $themeRaw) {
                    ForEach(LumaTheme.allCases) { Text($0.label).tag($0.rawValue) }
                }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
        }
    }
}

#if DEBUG
#Preview {
    RootView(model: LiveTunerModel())
}
#endif
