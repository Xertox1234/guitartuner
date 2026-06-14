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

struct RootView: View {
    var model: LiveTunerModel
    var accountModel: AccountModel
    var cardStore: TuningCardStore
    var gearStore: GearStoreModel
    @AppStorage("theme") private var themeRaw = LumaTheme.dark.rawValue
    private var theme: LumaTheme { LumaTheme(rawValue: themeRaw) ?? .dark }

    var body: some View {
        shell
            .tint(.lumaInTune)
            .preferredColorScheme(theme.colorScheme)
    }

    @ViewBuilder private var shell: some View {
        #if DEBUG
        TabView {
            LiveTunerScreen(model: model, accountModel: accountModel, cardStore: cardStore, gearStore: gearStore)
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
        LiveTunerScreen(model: model, accountModel: accountModel, cardStore: cardStore, gearStore: gearStore)
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
    RootView(model: LiveTunerModel(), accountModel: AccountModel(), cardStore: TuningCardStore(), gearStore: GearStoreModel())
}
#endif
