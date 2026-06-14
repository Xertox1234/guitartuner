import SwiftUI
import LumaDesignSystem

@main
struct LumaApp: App {
    @State private var model = LiveTunerModel()

    // Shared API actor — one JWT, one URLSession across all three models
    @State private var accountModel: AccountModel
    @State private var cardStore: TuningCardStore
    @State private var gearStore: GearStoreModel

    init() {
        LumaFonts.registerIfNeeded()
        let api = LumaAPI()  // single instance shared by all three models
        _accountModel = State(initialValue: AccountModel(api: api))
        _cardStore    = State(initialValue: TuningCardStore(api: api))
        _gearStore    = State(initialValue: GearStoreModel(api: api))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model, accountModel: accountModel, cardStore: cardStore, gearStore: gearStore)
        }
        #if os(macOS)
        .defaultSize(width: 440, height: 720)
        .windowResizability(.contentSize)
        #endif

        #if os(macOS)
        MenuBarExtra {
            MenuBarTuner(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
