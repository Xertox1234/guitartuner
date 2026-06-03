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

/// Root of the app.
///
/// **Release** ships a *single focused screen* (EXPERIENCE §3): the live tuner,
/// cold-opening straight into the breathing strobe — *the attract state is the
/// intro* (§10), no splash. **Debug** wraps that in a development `TabView` that
/// also surfaces the interactive strobe lab (Plan 03) and the design-system
/// gallery for previews/QA. Theme (light/dark/system) is applied here and picked
/// in Settings (release) or the gallery toolbar (debug) — same `@AppStorage` key.
struct RootView: View {
    /// The shared live tuner, owned by `LumaApp` (also drives the menu-bar strobe).
    var model: LiveTunerModel
    @AppStorage("theme") private var themeRaw = LumaTheme.dark.rawValue
    private var theme: LumaTheme { LumaTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        shell
            .tint(.lumaInTune)
            .preferredColorScheme(theme.colorScheme)
    }

    /// The shipping face is just the live tuner so cold open lands on the
    /// full-bleed breathing strobe; the lab + gallery are debug-only scaffolding.
    @ViewBuilder private var shell: some View {
        #if DEBUG
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
        #else
        LiveTunerScreen(model: model)
        #endif
    }

    #if DEBUG
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
    #endif
}

#if DEBUG
#Preview {
    RootView(model: LiveTunerModel())
}
#endif
