# LUMA v2 — iOS App Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional account registration, saved tuning cards, email affiliate opt-in, and an affiliate gear store to the LUMA iOS/macOS app via a swipe-up bottom drawer.

**Architecture:** All new code lives in `App/` (the glue layer). A `LumaAPI` actor owns URLSession + JWT refresh. Three `@MainActor @Observable` models (`AccountModel`, `TuningCardStore`, `GearStoreModel`) expose state to SwiftUI. A persistent bottom drawer (peeked at 80 pt, expandable) surfaces cards and the store without disturbing the single-screen tuner. Sign in with Apple is handled via `AuthenticationServices`; tokens are stored in the iOS Keychain.

**Tech Stack:** Swift 5.9, SwiftUI (iOS 17+ / macOS 14+), `AuthenticationServices`, `Security` framework (Keychain), `Swift Testing` framework for new tests, XcodeGen (run `xcodegen generate` after any `project.yml` changes — none needed here since XcodeGen scans `App/` recursively).

**Spec:** `docs/superpowers/specs/2026-06-14-monetization-design.md`
**Backend plan:** `docs/superpowers/plans/2026-06-14-monetization-backend.md` ← implement first
**Backend URL:** `https://luma-api.william-tower.workers.dev`

---

## File Map

All new files live under `App/`. XcodeGen auto-includes them.

```
App/
├── Networking/
│   ├── LumaConfig.swift       # API base URL constant
│   ├── LumaAPI.swift          # URLSession actor + JWT auto-refresh
│   └── APIModels.swift        # Codable request/response types + errors
├── Account/
│   ├── KeychainStore.swift    # Keychain read/write/delete (Security framework)
│   └── AccountModel.swift     # @Observable auth state; owns LumaAPI + KeychainStore
├── Tunings/
│   ├── TuningCard.swift       # TuningCard model (Codable, Identifiable)
│   └── TuningCardStore.swift  # @Observable fetch/save/delete + local JSON cache
├── Store/
│   ├── GearProduct.swift      # GearProduct model (Codable)
│   └── GearStoreModel.swift   # @Observable fetch + local JSON cache
└── Views/Monetization/
    ├── BottomDrawer.swift     # Persistent 3-detent sheet
    ├── AccountSheet.swift     # Sign in with Apple + email/password form
    ├── SaveCardSheet.swift    # Name + notes form; live settings snapshot
    └── GearStoreScreen.swift  # Category pills + product grid → openURL(Sweetwater)
```

**Modified files:**
- `App/LumaApp.swift` — inject three new models
- `App/LiveTunerScreen.swift` — attach `BottomDrawer` as a persistent sheet

---

### Task 1: Networking foundation — `LumaConfig`, `APIModels`, `LumaAPI`

**Files:**
- Create: `App/Networking/LumaConfig.swift`
- Create: `App/Networking/APIModels.swift`
- Create: `App/Networking/LumaAPI.swift`

No tests for `LumaAPI` in this task — tested via `AccountModel` + `TuningCardStore` tests in later tasks using a mock server.

- [ ] **Step 1: Create `App/Networking/LumaConfig.swift`**

Replace `WORKER_URL` with your deployed Worker URL (e.g. `https://luma-api.xyz.workers.dev`).

```swift
import Foundation

enum LumaConfig {
    static let apiBaseURL = URL(string: "WORKER_URL")!
}
```

- [ ] **Step 2: Create `App/Networking/APIModels.swift`**

```swift
import Foundation

// MARK: - Requests

struct RegisterRequest: Encodable {
    let email: String
    let password: String
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct AppleAuthRequest: Encodable {
    let identityToken: String
}

struct SaveCardRequest: Encodable {
    let name: String
    let notes: String
    let instrument: String
    let a4: Double
    let palette: String
    let stringsJson: String

    enum CodingKeys: String, CodingKey {
        case name, notes, instrument, a4, palette
        case stringsJson = "strings_json"
    }
}

struct SubscribeRequest: Encodable {
    let email: String?
}

// MARK: - Responses

struct MessageResponse: Decodable { let message: String }
struct TokenResponse: Decodable { let token: String }
struct SaveCardResponse: Decodable { let id: String }
// CardsResponse is defined in TuningCardStore.swift (references TuningCard)
// ProductsResponse is defined in GearStoreModel.swift (references GearProduct)
struct BoolResponse: Decodable { let subscribed: Bool?; let unsubscribed: Bool?; let deleted: Bool? }

// MARK: - Error

struct APIErrorBody: Decodable { let error: String }

enum LumaAPIError: LocalizedError {
    case unauthorized
    case server(String, Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:          return "Please sign in again."
        case .server(let msg, _):    return msg
        case .decoding(let err):     return "Unexpected response: \(err.localizedDescription)"
        }
    }
}

// Internal empty-body marker
struct EmptyBody: Encodable {}
```

- [ ] **Step 3: Create `App/Networking/LumaAPI.swift`**

```swift
import Foundation

/// The single networking actor for all LUMA API calls.
/// Automatically retries once on 401 after attempting a token refresh.
actor LumaAPI {
    private let baseURL: URL
    // nonisolated let: immutable, so safe to read from any concurrency context
    // without await. AccountModel.init reads this synchronously.
    nonisolated let keychain: KeychainStore

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    init(baseURL: URL = LumaConfig.apiBaseURL,
         keychain: KeychainStore = KeychainStore(service: "com.luma.tuner")) {
        self.baseURL = baseURL
        self.keychain = keychain
    }

    var jwt: String? { keychain.read(key: "jwt") }

    func setJWT(_ token: String) { keychain.write(key: "jwt", value: token) }
    func clearJWT() { keychain.delete(key: "jwt") }

    // MARK: - Convenience methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(method: "GET", path: path, body: nil as EmptyBody?)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        try await perform(method: "POST", path: path, body: body)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        try await perform(method: "DELETE", path: path, body: nil as EmptyBody?)
    }

    // MARK: - Core request

    private func perform<B: Encodable, T: Decodable>(
        method: String, path: String, body: B?
    ) async throws -> T {
        var req = makeRequest(method: method, path: path, body: body, token: jwt)
        let (data, response) = try await session.data(for: req)
        let http = response as! HTTPURLResponse

        if http.statusCode == 401 {
            guard let refreshed = try? await refreshToken() else {
                clearJWT()
                throw LumaAPIError.unauthorized
            }
            setJWT(refreshed)
            req = makeRequest(method: method, path: path, body: body, token: refreshed)
            let (data2, _) = try await session.data(for: req)
            return try decode(data2)
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error ?? "Unknown error"
            throw LumaAPIError.server(msg, http.statusCode)
        }
        return try decode(data)
    }

    private func makeRequest<B: Encodable>(
        method: String, path: String, body: B?, token: String?
    ) -> URLRequest {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body, !(body is EmptyBody) {
            req.httpBody = try? JSONEncoder().encode(body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw LumaAPIError.decoding(error) }
    }

    private func refreshToken() async throws -> String? {
        guard let current = jwt else { return nil }
        var req = URLRequest(url: baseURL.appendingPathComponent("auth/refresh"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(current)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: req)
        guard (response as! HTTPURLResponse).statusCode == 200 else { return nil }
        return (try? JSONDecoder().decode(TokenResponse.self, from: data))?.token
    }
}
```

- [ ] **Step 4: Build to confirm no compiler errors**

In Xcode: `Cmd+B` (or `xcodebuild -scheme LUMA -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -5`)

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add App/Networking/
git commit -m "feat(ios): networking foundation — LumaConfig, APIModels, LumaAPI"
```

---

### Task 2: Keychain helper + AccountModel

**Files:**
- Create: `App/Account/KeychainStore.swift`
- Create: `App/Account/AccountModel.swift`

Tests for `KeychainStore` run only on a real device or simulator (Keychain is sandboxed). Test `AccountModel` logic in Task 3 via UI smoke test.

- [ ] **Step 1: Create `App/Account/KeychainStore.swift`**

```swift
import Foundation
import Security

/// Thread-safe Keychain read/write for a single service namespace.
struct KeychainStore {
    let service: String

    func write(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 2: Create `App/Account/AccountModel.swift`**

```swift
import Foundation
import AuthenticationServices

@MainActor @Observable
final class AccountModel {
    var isSignedIn: Bool
    var isLoading = false
    var error: String?

    let api: LumaAPI

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        // Synchronously check Keychain on init — no async needed
        self.isSignedIn = api.keychain.read(key: "jwt") != nil
    }

    // MARK: - Email + password

    func register(email: String, password: String) async throws {
        isLoading = true; defer { isLoading = false }
        let _: MessageResponse = try await api.post("auth/register", body: RegisterRequest(email: email, password: password))
    }

    func login(email: String, password: String) async throws {
        isLoading = true; defer { isLoading = false }
        let response: TokenResponse = try await api.post("auth/login", body: LoginRequest(email: email, password: password))
        await api.setJWT(response.token)
        isSignedIn = true
    }

    // MARK: - Sign in with Apple

    func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            throw LumaAPIError.server("No identity token from Apple", 0)
        }
        isLoading = true; defer { isLoading = false }
        let response: TokenResponse = try await api.post("auth/apple", body: AppleAuthRequest(identityToken: token))
        await api.setJWT(response.token)
        isSignedIn = true
    }

    // MARK: - Email opt-in

    func subscribeMarketing(email: String?) async throws {
        let _: BoolResponse = try await api.post("email/subscribe", body: SubscribeRequest(email: email))
    }

    func unsubscribeMarketing() async throws {
        let _: BoolResponse = try await api.post("email/unsubscribe", body: SubscribeRequest(email: nil))
    }

    // MARK: - Sign out

    func signOut() async {
        await api.clearJWT()
        isSignedIn = false
    }
}
```

- [ ] **Step 3: Build to confirm no compiler errors**

`Cmd+B` in Xcode.

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add App/Account/
git commit -m "feat(ios): KeychainStore + AccountModel"
```

---

### Task 3: TuningCard model + TuningCardStore

**Files:**
- Create: `App/Tunings/TuningCard.swift`
- Create: `App/Tunings/TuningCardStore.swift`

- [ ] **Step 1: Create `App/Tunings/TuningCard.swift`**

`LumaPalette` and `Instrument` are both `String`-raw enums so they decode automatically.

```swift
import Foundation
import LumaDesignSystem

struct TuningCard: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var notes: String
    var instrument: Instrument
    var a4: Double
    var palette: LumaPalette
    private var stringsJson: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, notes, instrument, a4, palette
        case stringsJson  = "strings_json"
        case createdAt    = "created_at"
    }

    /// The decoded strings array, suitable for building a `Tuning`.
    var strings: [GuitarString] {
        (try? JSONDecoder().decode([GuitarString].self, from: Data(stringsJson.utf8))) ?? []
    }

    /// A `Tuning` that can be passed directly to `LiveTunerModel.setTuning(_:)`.
    var tuning: Tuning {
        Tuning(id: "card-\(id)", label: name, strings: strings)
    }

    /// Build the strings_json from a live array (used when saving).
    static func stringsJSON(_ strings: [GuitarString]) -> String {
        (try? String(data: JSONEncoder().encode(strings), encoding: .utf8)) ?? "[]"
    }
}
```

- [ ] **Step 2: Create `App/Tunings/TuningCardStore.swift`**

```swift
import Foundation
import LumaDesignSystem

@MainActor @Observable
final class TuningCardStore {
    var cards: [TuningCard] = []
    var isLoading = false
    var error: String?

    private let api: LumaAPI
    private let cacheURL: URL

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.cacheURL = support.appendingPathComponent("luma_tuning_cards.json")
        self.cards = loadCache()
    }

    // MARK: - Actions

    func fetch() async {
        isLoading = true; defer { isLoading = false }
        do {
            let response: CardsResponse = try await api.get("tunings")
            cards = response.cards
            persistCache()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Defined here because it references TuningCard (not in APIModels.swift)
    private struct CardsResponse: Decodable { let cards: [TuningCard] }

    func save(
        name: String, notes: String,
        instrument: Instrument, a4: Double,
        palette: LumaPalette, strings: [GuitarString]
    ) async throws {
        let body = SaveCardRequest(
            name: name, notes: notes,
            instrument: instrument.rawValue,
            a4: a4, palette: palette.rawValue,
            stringsJson: TuningCard.stringsJSON(strings)
        )
        let _: SaveCardResponse = try await api.post("tunings", body: body)
        await fetch()
    }

    func delete(_ card: TuningCard) async throws {
        let _: BoolResponse = try await api.delete("tunings/\(card.id)")
        cards.removeAll { $0.id == card.id }
        persistCache()
    }

    // MARK: - Local cache

    private func loadCache() -> [TuningCard] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([TuningCard].self, from: data)) ?? []
    }

    private func persistCache() {
        try? JSONEncoder().encode(cards).write(to: cacheURL, options: .atomic)
    }
}
```

- [ ] **Step 3: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add App/Tunings/
git commit -m "feat(ios): TuningCard model + TuningCardStore"
```

---

### Task 4: GearProduct model + GearStoreModel

**Files:**
- Create: `App/Store/GearProduct.swift`
- Create: `App/Store/GearStoreModel.swift`

- [ ] **Step 1: Create `App/Store/GearProduct.swift`**

```swift
import Foundation

struct GearProduct: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let category: String
    let name: String
    let description: String
    let priceHint: String
    let sweetwaterUrl: String
    let imageUrl: String
    let isFeatured: Bool
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, category, name, description
        case priceHint    = "price_hint"
        case sweetwaterUrl = "sweetwater_url"
        case imageUrl     = "image_url"
        case isFeatured   = "is_featured"
        case sortOrder    = "sort_order"
    }

    var affiliateURL: URL? { URL(string: sweetwaterUrl) }
}
```

- [ ] **Step 2: Create `App/Store/GearStoreModel.swift`**

```swift
import Foundation

@MainActor @Observable
final class GearStoreModel {
    var products: [GearProduct] = []
    var selectedCategory = "all"
    var isLoading = false
    var fetchError: String?

    private let api: LumaAPI
    private let cacheURL: URL

    init(api: LumaAPI = LumaAPI()) {
        self.api = api
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.cacheURL = support.appendingPathComponent("luma_gear_products.json")
        self.products = loadCache()
    }

    var featured: GearProduct? { products.first { $0.isFeatured } }

    var filtered: [GearProduct] {
        selectedCategory == "all" ? products : products.filter { $0.category == selectedCategory }
    }

    var categories: [String] {
        var seen = Set<String>()
        return products.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }

    func fetch() async {
        isLoading = true; defer { isLoading = false }
        do {
            let response: ProductsResponse = try await api.get("store/products")
            products = response.products
            persistCache()
        } catch {
            // If cache is non-empty, stay silent — stale products are fine
            if products.isEmpty { fetchError = "Unable to load products" }
        }
    }

    // Defined here because it references GearProduct (not in APIModels.swift)
    private struct ProductsResponse: Decodable { let products: [GearProduct] }

    private func loadCache() -> [GearProduct] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([GearProduct].self, from: data)) ?? []
    }

    private func persistCache() {
        try? JSONEncoder().encode(products).write(to: cacheURL, options: .atomic)
    }
}
```

- [ ] **Step 3: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add App/Store/
git commit -m "feat(ios): GearProduct + GearStoreModel"
```

---

### Task 5: BottomDrawer view

**Files:**
- Create: `App/Views/Monetization/BottomDrawer.swift`

- [ ] **Step 1: Create `App/Views/Monetization/BottomDrawer.swift`**

```swift
import SwiftUI
import LumaDesignSystem

/// The persistent bottom drawer: always peeked at 80 pt, swipe up for cards/store.
struct BottomDrawer: View {
    var model: LiveTunerModel
    @Bindable var cardStore: TuningCardStore
    @Bindable var accountModel: AccountModel
    @Bindable var gearStore: GearStoreModel

    @State private var showAccount = false
    @State private var showSaveCard = false
    @State private var showGearStore = false
    @Binding var detent: PresentationDetent

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dragHandle

                switch detent {
                case .height(80):
                    peekContent
                default:
                    expandedContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground).opacity(0.95))
        }
        .sheet(isPresented: $showAccount) {
            AccountSheet(accountModel: accountModel)
        }
        .sheet(isPresented: $showSaveCard) {
            SaveCardSheet(model: model, cardStore: cardStore, accountModel: accountModel)
        }
        .fullScreenCover(isPresented: $showGearStore) {
            GearStoreScreen(gearStore: gearStore)
        }
        .task { await cardStore.fetch() }
    }

    // MARK: - Peek strip

    private var dragHandle: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 8)
    }

    private var peekContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(cardStore.cards) { card in
                    CardChip(card: card)
                        .onTapGesture { loadCard(card) }
                }
                addChip
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if cardStore.cards.isEmpty {
                emptyState
            } else {
                cardGrid
            }
            if !accountModel.isSignedIn {
                signInNudge
            }
        }
        .padding(.horizontal, 16)
    }

    private var header: some View {
        HStack {
            Text("MY TUNINGS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .kerning(1)
            Spacer()
            Button("+ Save Current") { handleSave() }
                .font(.caption.bold())
                .foregroundStyle(.lumaInTune)
            Button { showGearStore = true } label: {
                Label("Store", systemImage: "bag")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cardStore.cards) { card in
                TuningCardCell(card: card)
                    .onTapGesture { loadCard(card) }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { try? await cardStore.delete(card) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            addCardCell
        }
        .padding(.bottom, 20)
    }

    private var addChip: some View {
        Button { handleSave() } label: {
            Image(systemName: "plus")
                .frame(width: 40, height: 36)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.secondary)
        }
    }

    private var addCardCell: some View {
        Button { handleSave() } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3)
                Text("Save tuning")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No saved tunings yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Save Current Tuning") { handleSave() }
                .buttonStyle(.borderedProminent)
                .tint(.lumaInTune)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var signInNudge: some View {
        Text("Sign in to sync tunings across devices")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func handleSave() {
        if accountModel.isSignedIn { showSaveCard = true }
        else { showAccount = true }
    }

    private func loadCard(_ card: TuningCard) {
        model.setInstrument(card.instrument)
        model.setTuning(card.tuning)
        model.a4 = card.a4
        // Note: palette is @AppStorage — set via UserDefaults key "strobePalette"
        UserDefaults.standard.set(card.palette.rawValue, forKey: "strobePalette")
    }
}

// MARK: - Sub-views

struct CardChip: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.name)
                .font(.caption.bold())
                .foregroundStyle(paletteColor(card.palette))
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(paletteColor(card.palette).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(paletteColor(card.palette).opacity(0.3)))
    }
}

struct TuningCardCell: View {
    let card: TuningCard
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name)
                .font(.caption.bold())
                .foregroundStyle(paletteColor(card.palette))
            Text("\(card.instrument == .guitar ? "Guitar" : "Bass") · \(Int(card.a4)) Hz · \(card.palette.label)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(card.strings.prefix(4)) { s in
                    Text(s.note)
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(paletteColor(card.palette).opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(paletteColor(card.palette))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
        .background(paletteColor(card.palette).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(paletteColor(card.palette).opacity(0.2)))
    }
}

private func paletteColor(_ palette: LumaPalette) -> Color {
    switch palette {
    case .aurora:  return .lumaInTune
    case .amber:   return Color(hue: 0.1, saturation: 0.8, brightness: 0.9)
    case .neon:    return Color(hue: 0.75, saturation: 0.8, brightness: 0.9)
    case .forest:  return Color(hue: 0.35, saturation: 0.7, brightness: 0.7)
    case .crimson: return Color(hue: 0.0, saturation: 0.8, brightness: 0.85)
    }
}
```

- [ ] **Step 2: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`. SwiftUI previews won't render without models but the build must pass.

- [ ] **Step 3: Commit**

```bash
git add App/Views/Monetization/BottomDrawer.swift
git commit -m "feat(ios): BottomDrawer — persistent 3-detent sheet with card grid"
```

---

### Task 6: AccountSheet (Sign in with Apple + email/password)

**Files:**
- Create: `App/Views/Monetization/AccountSheet.swift`

- [ ] **Step 1: Create `App/Views/Monetization/AccountSheet.swift`**

```swift
import SwiftUI
import AuthenticationServices

/// Registration / sign-in flow. Presented when unauthenticated user tries to save a card.
struct AccountSheet: View {
    @Bindable var accountModel: AccountModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = true
    @State private var showVerificationStep = false
    @State private var marketingOptIn = false
    @State private var marketingEmail = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if showVerificationStep {
                    verificationView
                } else {
                    authForm
                }
            }
            .navigationTitle(isRegistering ? "Create Account" : "Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
    }

    // MARK: - Auth form

    private var authForm: some View {
        Form {
            Section {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 44)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
            }

            if let err = errorMessage ?? accountModel.error {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button {
                    Task { await submitEmailAuth() }
                } label: {
                    if accountModel.isLoading {
                        ProgressView()
                    } else {
                        Text(isRegistering ? "Create Account" : "Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(accountModel.isLoading || email.isEmpty || password.isEmpty)
            }

            Section {
                Button(isRegistering ? "Already have an account? Sign in" : "Need an account? Create one") {
                    isRegistering.toggle()
                    errorMessage = nil
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Text("All audio is analyzed on your device and never sent anywhere. ")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                + Text("Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(.lumaInTune)
            }
        }
    }

    // MARK: - Verification / opt-in screen (email path)

    private var verificationView: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Check your inbox")
                        .font(.headline)
                    Text("We sent a verification link to ")
                        .font(.subheadline).foregroundStyle(.secondary)
                    + Text(email)
                        .font(.subheadline).foregroundStyle(.lumaInTune)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle(isOn: $marketingOptIn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get exclusive gear deals")
                            .font(.subheadline)
                        Text("Occasional handpicked Sweetwater deals. No spam. Unsubscribe anytime.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.lumaInTune)

                if marketingOptIn {
                    Text("We'll use **\(email)** for gear deal emails.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Continue") {
                    if marketingOptIn {
                        Task { try? await accountModel.subscribeMarketing(email: email) }
                    }
                    dismiss()
                }
                .frame(maxWidth: .infinity)
            }

            Section {
                Button("I'll skip for now") { dismiss() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Button("Resend verification email") {
                    Task { try? await accountModel.register(email: email, password: password) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Handlers

    private func submitEmailAuth() async {
        errorMessage = nil
        do {
            if isRegistering {
                try await accountModel.register(email: email, password: password)
                showVerificationStep = true
            } else {
                try await accountModel.login(email: email, password: password)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            Task {
                do {
                    try await accountModel.signInWithApple(credential)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            // User cancelled — ASAuthorizationError.canceled — ignore silently
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

- [ ] **Step 2: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add App/Views/Monetization/AccountSheet.swift
git commit -m "feat(ios): AccountSheet — Sign in with Apple + email/password + opt-in"
```

---

### Task 7: SaveCardSheet

**Files:**
- Create: `App/Views/Monetization/SaveCardSheet.swift`

- [ ] **Step 1: Create `App/Views/Monetization/SaveCardSheet.swift`**

```swift
import SwiftUI
import LumaDesignSystem

/// Presented after successful auth. Captures a name + notes for the current tuner state.
struct SaveCardSheet: View {
    var model: LiveTunerModel
    @Bindable var cardStore: TuningCardStore
    @Bindable var accountModel: AccountModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("strobePalette") private var palette: LumaPalette = .aurora
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Open G (Nashville)", text: $name)
                }

                Section("Notes (optional)") {
                    TextField("Great for slide, capo 5…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    snapshotPreview
                } header: {
                    Text("Saving With")
                } footer: {
                    Text("One tap on the card restores all of these settings.")
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save Card").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .navigationTitle("Save Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
        .onAppear { prefillName() }
    }

    private var snapshotPreview: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
            GridRow {
                Text("Instrument").foregroundStyle(.secondary)
                Text(model.instrument == .guitar ? "Guitar" : "Bass")
            }
            GridRow {
                Text("Tuning").foregroundStyle(.secondary)
                Text(model.tuning.label)
            }
            GridRow {
                Text("A4").foregroundStyle(.secondary)
                Text("\(Int(model.a4)) Hz")
            }
            GridRow {
                Text("Palette").foregroundStyle(.secondary)
                Text(palette.label).foregroundStyle(paletteColor(palette))
            }
        }
        .font(.subheadline)
    }

    private func prefillName() {
        if name.isEmpty { name = model.tuning.label }
    }

    private func save() async {
        isSaving = true; defer { isSaving = false }
        errorMessage = nil
        do {
            try await cardStore.save(
                name: name.trimmingCharacters(in: .whitespaces),
                notes: notes,
                instrument: model.instrument,
                a4: model.a4,
                palette: palette,
                strings: model.tuning.strings
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func paletteColor(_ palette: LumaPalette) -> Color {
    switch palette {
    case .aurora:  return .lumaInTune
    case .amber:   return Color(hue: 0.1, saturation: 0.8, brightness: 0.9)
    case .neon:    return Color(hue: 0.75, saturation: 0.8, brightness: 0.9)
    case .forest:  return Color(hue: 0.35, saturation: 0.7, brightness: 0.7)
    case .crimson: return Color(hue: 0.0, saturation: 0.8, brightness: 0.85)
    }
}
```

- [ ] **Step 2: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add App/Views/Monetization/SaveCardSheet.swift
git commit -m "feat(ios): SaveCardSheet — snapshot current tuner state into a named card"
```

---

### Task 8: GearStoreScreen

**Files:**
- Create: `App/Views/Monetization/GearStoreScreen.swift`

- [ ] **Step 1: Create `App/Views/Monetization/GearStoreScreen.swift`**

```swift
import SwiftUI

/// Full-screen affiliate store. Products fetched from Cloudflare, tap opens Sweetwater in Safari.
struct GearStoreScreen: View {
    @Bindable var gearStore: GearStoreModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    categoryPills

                    if let featured = gearStore.featured, gearStore.selectedCategory == "all" {
                        FeaturedBanner(product: featured) { open(featured) }
                    }

                    if gearStore.isLoading && gearStore.products.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else if let err = gearStore.fetchError, gearStore.products.isEmpty {
                        ContentUnavailableView(err, systemImage: "bag.badge.questionmark")
                    } else {
                        productGrid
                    }

                    affiliateDisclosure
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Gear Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(.lumaInTune)
        .task { await gearStore.fetch() }
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill("all", label: "All")
                ForEach(gearStore.categories, id: \.self) { cat in
                    pill(cat, label: cat.capitalized)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(_ category: String, label: String) -> some View {
        Button {
            gearStore.selectedCategory = category
        } label: {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    gearStore.selectedCategory == category ? Color.lumaInTune : Color.secondary.opacity(0.12),
                    in: Capsule()
                )
                .foregroundStyle(gearStore.selectedCategory == category ? Color.black : Color.primary)
        }
    }

    // MARK: - Product grid

    private var productGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(gearStore.filtered) { product in
                ProductCard(product: product) { open(product) }
            }
        }
    }

    private var affiliateDisclosure: some View {
        Text("Affiliate disclosure: LUMA earns a small commission on Sweetwater purchases at no extra cost to you.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func open(_ product: GearProduct) {
        guard let url = product.affiliateURL else { return }
        openURL(url)
    }
}

// MARK: - Sub-views

struct FeaturedBanner: View {
    let product: GearProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lumaInTune.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "guitars").font(.title2).foregroundStyle(.lumaInTune))

                VStack(alignment: .leading, spacing: 2) {
                    Text("FEATURED")
                        .font(.caption2.bold())
                        .foregroundStyle(.lumaInTune)
                        .kerning(1)
                    Text(product.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    if !product.priceHint.isEmpty {
                        Text(product.priceHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("View →")
                    .font(.caption.bold())
                    .foregroundStyle(.lumaInTune)
            }
            .padding(14)
            .background(Color.lumaInTune.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.lumaInTune.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}

struct ProductCard: View {
    let product: GearProduct
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 60)
                    .overlay(Image(systemName: icon(for: product.category)).font(.title2).foregroundStyle(.secondary))

                Text(product.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !product.priceHint.isEmpty {
                    Text(product.priceHint)
                        .font(.caption2)
                        .foregroundStyle(.lumaInTune)
                }

                Text("Shop →")
                    .font(.caption2.bold())
                    .foregroundStyle(.lumaInTune)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.lumaInTune.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private func icon(for category: String) -> String {
        switch category {
        case "strings": return "music.note"
        case "tuners":  return "tuningfork"
        case "guitars": return "guitars"
        case "basses":  return "guitars"
        case "picks":   return "triangle"
        default:        return "bag"
        }
    }
}
```

- [ ] **Step 2: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add App/Views/Monetization/GearStoreScreen.swift
git commit -m "feat(ios): GearStoreScreen — Sweetwater affiliate store with category filtering"
```

---

### Task 9: Wire everything into LumaApp + LiveTunerScreen

**Files:**
- Modify: `App/LumaApp.swift`
- Modify: `App/LiveTunerScreen.swift`

- [ ] **Step 1: Modify `App/LumaApp.swift`**

The three new models share one `LumaAPI` instance so they share the same Keychain/JWT.

```swift
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
```

- [ ] **Step 2: Update `App/RootView.swift` to thread models through**

The `#else` branch (release) needs to pass models to `LiveTunerScreen`. Add parameters:

```swift
import SwiftUI
import LumaDesignSystem

// ... (LumaTheme enum unchanged) ...

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
```

- [ ] **Step 3: Add `BottomDrawer` to `App/LiveTunerScreen.swift`**

Add three new parameters and the drawer sheet. The key change is adding the `.sheet(isPresented: .constant(true))` block at the end of the `body` ZStack. Find the `body` property and add inside the outermost `ZStack`:

Add these stored properties to `LiveTunerScreen`:
```swift
var accountModel: AccountModel
var cardStore: TuningCardStore
var gearStore: GearStoreModel
@State private var drawerDetent: PresentationDetent = .height(80)
```

Add this modifier to the outermost `ZStack` in `body` (after `.ignoresSafeArea()` or at the end of the view modifiers):

```swift
#if os(iOS)
.sheet(isPresented: .constant(true)) {
    BottomDrawer(
        model: model,
        cardStore: cardStore,
        accountModel: accountModel,
        gearStore: gearStore,
        detent: $drawerDetent
    )
    .presentationDetents([.height(80), .medium, .fraction(0.9)], selection: $drawerDetent)
    .presentationBackgroundInteraction(.enabled(upThrough: .height(80)))
    .interactiveDismissDisabled()
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(16)
}
#endif
```

- [ ] **Step 4: Build**

`Cmd+B`. Expected: `BUILD SUCCEEDED`

If the compiler complains about `LiveTunerScreen` init sites in previews, update those preview calls to include the three new parameters using `AccountModel()`, `TuningCardStore()`, `GearStoreModel()`.

- [ ] **Step 5: Commit**

```bash
git add App/LumaApp.swift App/RootView.swift App/LiveTunerScreen.swift
git commit -m "feat(ios): wire AccountModel + TuningCardStore + GearStoreModel into app; attach BottomDrawer"
```

---

### Task 10: Smoke test on device / simulator

**No new files.** This task validates the end-to-end flow works before closing the feature.

- [ ] **Step 1: Run on iOS Simulator**

In Xcode: select an iPhone 16 simulator, hit Run (`Cmd+R`).

Expected: app launches to the strobe screen, the bottom drawer peeks at the bottom showing the pull handle.

- [ ] **Step 2: Test the drawer**

- Swipe up on the drawer handle → cards grid + "Save Current" + "Store" button appear
- Swipe down → snaps back to peeked state
- Tapping the strobe area collapses the drawer

Expected: smooth snap behavior, tuner remains interactive in peeked state.

- [ ] **Step 3: Test registration flow**

- Tap "Save Current" → `AccountSheet` presents
- Enter an email + password (8+ chars) → tap "Create Account"
- Expected: "Check your inbox" screen with opt-in checkbox

- [ ] **Step 4: Test gear store**

- Swipe up drawer → tap "Store" → `GearStoreScreen` appears
- If backend is live: products load and category pills filter them
- If backend not yet live: empty state shows cleanly

- [ ] **Step 5: Test Sign in with Apple (device only)**

Sign in with Apple cannot be tested in the simulator. On a real device:
- Tap "Save Current" → `AccountSheet` → tap "Sign in with Apple"
- Authenticate with Face ID / Touch ID
- Expected: sheet dismisses, `AccountModel.isSignedIn == true`

- [ ] **Step 6: Commit test pass note**

```bash
git commit --allow-empty -m "test(ios): smoke test passed — drawer, registration flow, gear store render correctly"
```

---

### Task 11: Add Sign in with Apple capability to entitlements

Sign in with Apple requires an entitlement — without it, the Apple button will fail at runtime.

**Files:**
- Modify: `App/LUMA.entitlements`

- [ ] **Step 1: Open `App/LUMA.entitlements` and add the Sign in with Apple key**

Read the current file first, then add:

```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

Add it inside the `<dict>` alongside the existing entitlements.

- [ ] **Step 2: Enable in Apple Developer Portal**

Go to [developer.apple.com](https://developer.apple.com) → Certificates, IDs & Profiles → your App ID `com.luma.tuner` → Edit → enable "Sign In with Apple" → Save.

- [ ] **Step 3: Build + verify no entitlement error**

`Cmd+B` on a device target.

Expected: `BUILD SUCCEEDED`, no "Missing entitlement" warning.

- [ ] **Step 4: Commit**

```bash
git add App/LUMA.entitlements
git commit -m "feat(ios): add Sign in with Apple entitlement"
```
