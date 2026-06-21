# Gear Store — Seed Catalog + Discoverable iOS Entry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seed the affiliate gear-store catalog with a realistic starter set and add an at-rest-visible "Gear Store" entry point to the iOS tuner screen, so the (currently empty, undiscoverable) store becomes functional.

**Architecture:** Two cohesive parts. **(1)** A backend seed (`workers/luma-api/seed/store_products.sql`) populates the `store_products` D1 table read by the live `GET /store/products` route. **(2)** A `#if os(iOS)` bag icon in `LiveTunerScreen.topChrome` presents the existing `GearStoreScreen`. No new types, no package-boundary changes. Two early verification gates de-risk the untested seams before any production write.

**Tech Stack:** Cloudflare Workers + D1 + Wrangler 3.x (TypeScript/Hono backend); Swift 5.9 / SwiftUI (iOS 17+ / macOS 14+); Swift Testing (`@Test`/`#expect`); Vitest (`@cloudflare/vitest-pool-workers`); XcodeGen.

**Spec:** `docs/superpowers/specs/2026-06-21-gear-store-seed-and-discoverability-design.md`
**Backend URL:** `https://luma-api.william-tower.workers.dev`
**D1 database name:** `luma`

## Global Constraints

- **Platforms:** iOS 17+ / macOS 14+. All new monetization UI is **`#if os(iOS)`-gated** — macOS is out of scope this round (tracked in `docs/todos/P3-macos-network-entitlement.md`).
- **Networking only in `App/` via `LumaAPI`.** This plan adds no networking — the `GET /store/products` path already exists.
- **No force-unwrapping** in production code paths.
- **Swift Testing** (`@Test`/`#expect`, `@testable import LUMA`) for new Swift tests, placed in `LUMA/Tests/` (target `LUMATests`, platform macOS, run via `xcodebuild test -scheme LUMA`).
- **Template URLs:** every `sweetwater_url` is a Sweetwater **search** URL with no affiliate ID, marked for affiliate-wrapping before App Store launch. Swaps are made by **editing the seed file and re-applying** — never by hand-editing production D1 (`INSERT OR REPLACE` would clobber it).
- **Idempotent seed:** `INSERT OR REPLACE` keyed on stable string IDs.
- **Commit trailer:** end every commit message with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Gate ordering:** Gate A (Swift decode, Task 2) must be green **before** the production seed (Task 4). The production `--remote` write happens **only with explicit user go-ahead.**

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `workers/luma-api/seed/store_products.sql` | Create | Idempotent starter catalog (12 products, 2 featured) |
| `LUMA/Tests/GearProductDecodeTests.swift` | Create | Gate A — proves `GearProduct` decodes the D1 wire format |
| `App/Store/GearProduct.swift` | Modify *(only if Gate A fails)* | Lenient `is_featured` decode (Int→Bool) |
| `App/LiveTunerScreen.swift` | Modify | Top-chrome bag icon + `.fullScreenCover` presenting `GearStoreScreen` |
| `App/Views/Monetization/BottomDrawer.swift` | Modify *(only if Gate B fails)* | Fallback: drive store cover via shared binding |

---

### Task 1: Backend — seed the gear-store catalog

**Files:**
- Create: `workers/luma-api/seed/store_products.sql`

**Interfaces:**
- Consumes: existing `store_products` schema from `workers/luma-api/migrations/0001_initial.sql` — columns `(id, category, name, description, price_hint, sweetwater_url, image_url, is_featured, sort_order)`.
- Produces: 12 rows readable by `GET /store/products` (route in `src/store.ts`, orders `is_featured DESC, sort_order ASC`).

- [ ] **Step 1: Create `workers/luma-api/seed/store_products.sql`**

```sql
-- LUMA gear store — starter catalog seed (v1).
--
-- TEMPLATE URLS: every sweetwater_url below is a Sweetwater SEARCH url with no
-- affiliate id. They resolve to a real page today so the in-app tap-through is
-- testable. Before App Store launch, replace each with an affiliate-wrapped
-- product url by EDITING THIS FILE and re-applying it:
--   npx wrangler d1 execute luma --remote --file=seed/store_products.sql
-- Do NOT hand-edit urls directly in production D1 — INSERT OR REPLACE here would
-- silently clobber them back to the template on the next re-seed.
--
-- Idempotent: INSERT OR REPLACE keyed on stable string ids.

INSERT OR REPLACE INTO store_products
  (id, category, name, description, price_hint, sweetwater_url, image_url, is_featured, sort_order)
VALUES
  ('prod-elixir-nanoweb-light', 'strings', 'Elixir Nanoweb Electric, Light (.010-.046)', 'Long-life coated electric strings, light gauge.', '~$13', 'https://www.sweetwater.com/store/search?s=Elixir+Nanoweb+Electric+Light', '', 1, 0),
  ('prod-snark-st2', 'tuners', 'Snark ST-2 Clip-On Tuner', 'Clip-on chromatic tuner for guitar and bass.', '~$15', 'https://www.sweetwater.com/store/search?s=Snark+ST-2', '', 1, 1),
  ('prod-daddario-exl110', 'strings', 'D''Addario EXL110 Nickel Wound', 'Regular light nickel-wound electric strings.', '~$6', 'https://www.sweetwater.com/store/search?s=DAddario+EXL110', '', 0, 2),
  ('prod-ernieball-slinky', 'strings', 'Ernie Ball Regular Slinky', 'Classic .010-.046 nickel-wound electric strings.', '~$6', 'https://www.sweetwater.com/store/search?s=Ernie+Ball+Regular+Slinky', '', 0, 3),
  ('prod-elixir-bass-light', 'strings', 'Elixir Nanoweb Bass, 4-String Light', 'Coated long-life bass strings, light gauge.', '~$30', 'https://www.sweetwater.com/store/search?s=Elixir+Nanoweb+Bass+Light', '', 0, 4),
  ('prod-daddario-exl170', 'strings', 'D''Addario EXL170 Bass', 'Light nickel-wound long-scale bass strings.', '~$22', 'https://www.sweetwater.com/store/search?s=DAddario+EXL170', '', 0, 5),
  ('prod-tc-polytune-clip', 'tuners', 'TC Electronic PolyTune Clip', 'Polyphonic clip-on tuner with strobe mode.', '~$49', 'https://www.sweetwater.com/store/search?s=TC+Electronic+PolyTune+Clip', '', 0, 6),
  ('prod-boss-tu3', 'tuners', 'Boss TU-3 Chromatic Tuner Pedal', 'Stage-grade chromatic tuner pedal.', '~$105', 'https://www.sweetwater.com/store/search?s=Boss+TU-3', '', 0, 7),
  ('prod-dunlop-tortex-60', 'picks', 'Dunlop Tortex Standard .60mm (72-pack)', 'Classic .60mm picks, bulk pack.', '~$22', 'https://www.sweetwater.com/store/search?s=Dunlop+Tortex+Standard+.60mm', '', 0, 8),
  ('prod-fender-351-picks', 'picks', 'Fender 351 Celluloid Picks (12-pack)', 'Medium celluloid picks, 12-pack.', '~$5', 'https://www.sweetwater.com/store/search?s=Fender+351+Celluloid+Picks', '', 0, 9),
  ('prod-fender-player2-strat', 'guitars', 'Fender Player II Stratocaster', 'Versatile double-cut electric guitar.', '~$799', 'https://www.sweetwater.com/store/search?s=Fender+Player+II+Stratocaster', '', 0, 10),
  ('prod-fender-player2-pbass', 'basses', 'Fender Player II Precision Bass', 'Iconic P-Bass tone, modern build.', '~$849', 'https://www.sweetwater.com/store/search?s=Fender+Player+II+Precision+Bass', '', 0, 11);
```

- [ ] **Step 2: Apply schema + seed to the LOCAL D1 and verify the row count**

Run (from `workers/luma-api/`):
```bash
cd workers/luma-api
npx wrangler d1 migrations apply luma --local
npx wrangler d1 execute luma --local --file=seed/store_products.sql
npx wrangler d1 execute luma --local --command "SELECT count(*) AS n, sum(is_featured) AS featured FROM store_products"
```
Expected: a result row with `n = 12` and `featured = 2`.

- [ ] **Step 3: Run the worker test suite to confirm nothing regressed**

Run (from `workers/luma-api/`):
```bash
npm test
```
Expected: PASS — including the existing `test/store.test.ts` (which manages its own rows in `beforeEach`, so the seed file does not affect it).

- [ ] **Step 4: Commit**

```bash
git add workers/luma-api/seed/store_products.sql
git commit -m "feat(backend): seed gear-store starter catalog (12 products, template URLs)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Gate A — verify `GearProduct` decodes the D1 wire format

The store has **never decoded a real row** (it has always been empty). `GET /store/products` does `SELECT *` then `JSON.stringify`, so `is_featured`/`sort_order` (SQLite `INTEGER`) arrive as JSON **numbers** (`1`/`0`) — confirmed by `test/store.test.ts` typing the field as `is_featured: number`. `GearProduct.isFeatured` is a Swift `Bool`, and Foundation's `JSONDecoder` may throw `typeMismatch` on `1`→`Bool`. `[GearProduct]` decodes all-or-nothing, so one failing row blanks the whole catalog. This task proves the seam empirically **before** the production write.

**Files:**
- Create: `LUMA/Tests/GearProductDecodeTests.swift`
- Modify (only if the test fails): `App/Store/GearProduct.swift`

**Interfaces:**
- Consumes: `GearProduct` (internal struct, `App/Store/GearProduct.swift`) — `CodingKeys` map snake_case → camelCase; fields `id, category, name, description, priceHint, sweetwaterUrl, imageUrl, isFeatured: Bool, sortOrder: Int`.
- Produces: confidence (and, if needed, a hardened `GearProduct.init(from:)`) that a real route payload decodes into `[GearProduct]`.

- [ ] **Step 1: Write the failing-or-passing decode test**

Create `LUMA/Tests/GearProductDecodeTests.swift`:
```swift
import Foundation
import Testing
@testable import LUMA

@Suite("GearProduct decoding (D1 wire format)")
struct GearProductDecodeTests {
    // Mirrors exactly what GET /store/products emits: SELECT * from D1, so
    // is_featured / sort_order are SQLite INTEGER and arrive as JSON NUMBERS
    // (1 / 0), not booleans. This is the previously-untested seam.
    private let payload = """
    {"products":[
      {"id":"prod-snark-st2","category":"tuners","name":"Snark ST-2 Clip-On Tuner","description":"Clip-on chromatic tuner.","price_hint":"~$15","sweetwater_url":"https://www.sweetwater.com/store/search?s=Snark+ST-2","image_url":"","is_featured":1,"sort_order":0},
      {"id":"prod-dunlop-tortex-60","category":"picks","name":"Dunlop Tortex Standard .60mm","description":"Classic .60mm picks.","price_hint":"~$22","sweetwater_url":"https://www.sweetwater.com/store/search?s=Dunlop+Tortex","image_url":"","is_featured":0,"sort_order":8}
    ]}
    """

    // GearStoreModel.ProductsResponse is private; this mirrors its shape.
    private struct Wrapper: Decodable { let products: [GearProduct] }

    @Test func decodesIntegerBackedBooleanAndAllFields() throws {
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: Data(payload.utf8))
        #expect(wrapper.products.count == 2)
        let snark = try #require(wrapper.products.first)
        #expect(snark.id == "prod-snark-st2")
        #expect(snark.isFeatured == true)            // JSON 1 -> Bool true
        #expect(snark.sortOrder == 0)
        #expect(snark.priceHint == "~$15")
        #expect(snark.sweetwaterUrl.contains("sweetwater.com"))
        #expect(wrapper.products[1].isFeatured == false)  // JSON 0 -> Bool false
    }
}
```

- [ ] **Step 2: Run the test and record the result**

Run (from repo root):
```bash
xcodebuild test -scheme LUMA -destination 'platform=macOS' \
  -only-testing:LUMATests/GearProductDecodeTests 2>&1 | tail -20
```
Two possible outcomes:
- **PASS** → the seam is fine. Skip Step 3, go to Step 4.
- **FAIL** with a `typeMismatch`/`Bool` decoding error → the integer-backed boolean does not coerce. Do Step 3.

- [ ] **Step 3: (Only if Step 2 FAILED) Harden `GearProduct` with a lenient `is_featured` decode**

Replace the entire contents of `App/Store/GearProduct.swift` with:
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
        case priceHint     = "price_hint"
        case sweetwaterUrl  = "sweetwater_url"
        case imageUrl      = "image_url"
        case isFeatured    = "is_featured"
        case sortOrder     = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        category      = try c.decode(String.self, forKey: .category)
        name          = try c.decode(String.self, forKey: .name)
        description   = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        priceHint     = try c.decodeIfPresent(String.self, forKey: .priceHint) ?? ""
        sweetwaterUrl = try c.decode(String.self, forKey: .sweetwaterUrl)
        imageUrl      = try c.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        // D1 INTEGER arrives as a JSON number (1/0). Accept Bool or Int so both
        // the route payload and the locally-cached (Bool-encoded) JSON decode.
        if let b = try? c.decode(Bool.self, forKey: .isFeatured) {
            isFeatured = b
        } else {
            isFeatured = (try c.decode(Int.self, forKey: .isFeatured)) != 0
        }
        sortOrder     = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    var affiliateURL: URL? { URL(string: sweetwaterUrl) }
}
```
This provides only `init(from:)`; Swift still synthesizes `encode(to:)` (used by the local cache), which writes `isFeatured` as a JSON boolean — round-trip-safe with the lenient decoder above.

Re-run Step 2's command. Expected now: **PASS**.

- [ ] **Step 4: Commit**

```bash
git add LUMA/Tests/GearProductDecodeTests.swift App/Store/GearProduct.swift
git commit -m "test(ios): Gate A — GearProduct decodes D1 integer-backed booleans

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
*(If Step 3 was skipped, only `GearProductDecodeTests.swift` is staged — that is fine.)*

---

### Task 3: iOS — top-chrome gear-store entry point (+ Gate B)

**Files:**
- Modify: `App/LiveTunerScreen.swift`
- Modify (only if Gate B fails): `App/Views/Monetization/BottomDrawer.swift`

**Interfaces:**
- Consumes: `gearStore: GearStoreModel` (already a `LiveTunerScreen` property, threaded from `LumaApp`); `GearStoreScreen(gearStore:)` (`App/Views/Monetization/GearStoreScreen.swift`, `#if os(iOS)`); `EdgeIconButton(systemImage:accessibilityLabel:action:)` (`LumaDesignSystem`).
- Produces: an at-rest-visible bag icon in `topChrome` that presents `GearStoreScreen`.

- [ ] **Step 1: Add the presentation state**

In `App/LiveTunerScreen.swift`, find:
```swift
    @State private var showSettings = false
```
Replace with:
```swift
    @State private var showSettings = false
    @State private var showGearStore = false
```

- [ ] **Step 2: Add the bag icon to `topChrome`**

In `App/LiveTunerScreen.swift`, find this block inside `topChrome`:
```swift
            HStack(spacing: Space.s3) {
                InputSource(source: inputBinding)
                EdgeIconButton(systemImage: "arrow.up.left.and.arrow.down.right",
                               accessibilityLabel: "Stage Mode") {
                    withAnimation(.easeInOut(duration: 0.3)) { stageMode = true }
                }
                SettingsButton { showSettings = true }
            }
```
Replace with:
```swift
            HStack(spacing: Space.s3) {
                InputSource(source: inputBinding)
                EdgeIconButton(systemImage: "arrow.up.left.and.arrow.down.right",
                               accessibilityLabel: "Stage Mode") {
                    withAnimation(.easeInOut(duration: 0.3)) { stageMode = true }
                }
                #if os(iOS)
                EdgeIconButton(systemImage: "bag", accessibilityLabel: "Gear Store") {
                    showGearStore = true
                }
                #endif
                SettingsButton { showSettings = true }
            }
```

- [ ] **Step 3: Present `GearStoreScreen` as a full-screen cover**

In `App/LiveTunerScreen.swift`, find the existing iOS drawer block (ends with `#endif` after the drawer `.sheet`):
```swift
        #if os(iOS)
        .sheet(isPresented: .constant(true)) {
            BottomDrawer(
                model: model,
                cardStore: cardStore,
                accountModel: accountModel,
                gearStore: gearStore,
                palette: $palette,
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
Add the `.fullScreenCover` immediately before the `#endif`, so the block becomes:
```swift
        #if os(iOS)
        .sheet(isPresented: .constant(true)) {
            BottomDrawer(
                model: model,
                cardStore: cardStore,
                accountModel: accountModel,
                gearStore: gearStore,
                palette: $palette,
                detent: $drawerDetent
            )
            .presentationDetents([.height(80), .medium, .fraction(0.9)], selection: $drawerDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(80)))
            .interactiveDismissDisabled()
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(16)
        }
        .fullScreenCover(isPresented: $showGearStore) {
            GearStoreScreen(gearStore: gearStore)
        }
        #endif
```

- [ ] **Step 4: Refresh code issues and build**

Run `XcodeRefreshCodeIssuesInFile` on `App/LiveTunerScreen.swift` — expect no errors. Then build for an iOS simulator:
```bash
xcodebuild build -scheme LUMA \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Gate B — verify the cover presents over the permanent drawer on a simulator**

`LiveTunerScreen` already presents the drawer as a permanently-open `.sheet`; this adds a base-level `.fullScreenCover` on the same view. Confirm they don't conflict ("attempt to present while already presenting"). Run the app on an iPhone simulator (e.g. via `build_run_sim`), then:
- Confirm the **bag icon is visible in the top chrome at rest** (no gesture).
- Tap it. Expected: `GearStoreScreen` presents full-screen. *(Before Task 4 the catalog is still empty, so the screen shows its `ContentUnavailableView` empty state — that is the correct pre-seed result; what matters here is that it PRESENTS with no console error/crash.)*
- Dismiss ("Close"). Expected: returns to the tuner with the drawer still peeking.

**If Gate B fails** (cover does not appear, or an "already presenting" error logs), apply the fallback — route the bag tap through the drawer's existing, proven cover via a shared binding:

  1. In `App/LiveTunerScreen.swift` Step 3, **delete** the `.fullScreenCover(isPresented: $showGearStore) { GearStoreScreen(gearStore: gearStore) }` you added, and instead pass the binding into the drawer by changing the `BottomDrawer(...)` call to include:
     ```swift
                 gearStore: gearStore,
                 showGearStore: $showGearStore,
                 palette: $palette,
                 detent: $drawerDetent
     ```
  2. In `App/Views/Monetization/BottomDrawer.swift`, change:
     ```swift
         @State private var showGearStore = false
     ```
     to:
     ```swift
         @Binding var showGearStore: Bool
     ```
     (The drawer already has `.fullScreenCover(isPresented: $showGearStore) { GearStoreScreen(gearStore: gearStore) }` and a header "Store" button that sets `showGearStore = true`; both now use the shared binding.)
  3. Update the two `#Preview` blocks at the bottom of `BottomDrawer.swift` to pass `showGearStore: .constant(false)` in each `BottomDrawer(...)` call.
  4. Re-run Step 4 (build) and Step 5 (Gate B). Expected: bag tap now presents the store from within the drawer's presentation, no conflict.

- [ ] **Step 6: Commit**

```bash
git add App/LiveTunerScreen.swift App/Views/Monetization/BottomDrawer.swift
git commit -m "feat(ios): add discoverable top-chrome gear-store entry point

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```
*(If the Gate B fallback was not needed, only `LiveTunerScreen.swift` is staged — that is fine.)*

---

### Task 4: Production seed + end-to-end verification (gated)

**No code files.** This applies the seed to production D1 and verifies the whole flow. **Preconditions:** Task 2 (Gate A) is green, and the user has given **explicit go-ahead** for the live `--remote` write.

- [ ] **Step 1: Confirm Wrangler is authenticated for the production account**

```bash
cd workers/luma-api
npx wrangler whoami
```
Expected: shows the account owning the `luma` D1 database. If not, run `npx wrangler login` (or set `CLOUDFLARE_API_TOKEN`) first.

- [ ] **Step 2: Apply the seed to PRODUCTION D1 (explicit go-ahead required)**

```bash
cd workers/luma-api
npx wrangler d1 execute luma --remote --file=seed/store_products.sql
npx wrangler d1 execute luma --remote --command "SELECT count(*) AS n, sum(is_featured) AS featured FROM store_products"
```
Expected: `n = 12`, `featured = 2`. **This D1 `SELECT` is the authoritative confirmation the seed worked** (see Step 3 for why the HTTP endpoint may lag).

- [ ] **Step 3: Verify the public endpoint reflects the catalog (mind the edge cache)**

```bash
curl -s "https://luma-api.william-tower.workers.dev/store/products" | python3 -m json.tool | head -30
```
The route sets `Cache-Control: s-maxage=3600`, so Cloudflare's edge (and any prior client cache) may serve the old `{"products":[]}` for up to an hour. If the response is still empty:
- Purge the Cloudflare cache for this URL (dashboard → Caching → Purge, or the cache-purge API), **or**
- Append a one-off cache-buster to confirm origin is correct: `curl -s "https://luma-api.william-tower.workers.dev/store/products?cb=1" | head -c 400` — this should return the 12 products immediately.

Do not treat a cached-empty HTTP response as a seed failure — Step 2's D1 count is authoritative.

- [ ] **Step 4: End-to-end on a FRESH simulator install**

Install/run the app on a simulator that has **no prior URLSession cache** for the endpoint (erase the simulator or delete+reinstall the app, so a stale empty fetch isn't cached on-device). Then:
- Bag icon visible in the top chrome **at rest**.
- Tap bag → `GearStoreScreen` presents and shows the **12 seeded products**; the featured banner shows a featured item; category pills (All / Strings / Tuners / Guitars / Basses / Picks) filter the grid.
- Tap a product → Safari opens the Sweetwater search page for that product.

- [ ] **Step 5: Commit the verification pass note**

```bash
git commit --allow-empty -m "test(ios): e2e — seeded gear store renders and tap-through opens Sweetwater

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Finishing

After Task 4 passes, use **superpowers:finishing-a-development-branch** to open a PR from `feat/gear-store-seed-discoverability` (or merge per your workflow). Note in the PR description that the `sweetwater_url`s are template search URLs to be swapped for affiliate-wrapped URLs before App Store launch, and that macOS store parity remains tracked in `docs/todos/P3-macos-network-entitlement.md`.

---

## Self-Review

**Spec coverage:**
- Spec §3 (seed catalog, idempotent, template URLs, apply+verify, ~12 products/2 featured) → Task 1 + Task 4. ✓
- Spec §3.2 re-seed-clobber warning → seed file header (Task 1 Step 1). ✓
- Spec §4 (top-chrome bag, `@State showGearStore`, `.fullScreenCover`, `#if os(iOS)`, drawer button unchanged) → Task 3. ✓
- Spec §4 presentation-conflict risk + fallback → Task 3 Step 5. ✓
- Spec §8 Gate A (Codable decode, Int→Bool, all-or-nothing) → Task 2. ✓
- Spec §8 Gate B (presentation on real iOS run) → Task 3 Step 5. ✓
- Spec §8 backend tests stay green / iOS build / manual e2e → Task 1 Step 3, Task 3 Step 4, Task 4 Step 4. ✓
- Spec §9 out-of-scope (macOS, real links, IAP) → Global Constraints + Finishing note. ✓

**Placeholder scan:** No TBD/TODO; all code blocks complete; both conditional branches (Gate A fix, Gate B fallback) include full code. ✓

**Type consistency:** `showGearStore: Bool` state/binding consistent across Task 3 and the fallback; `GearProduct` field names/`CodingKeys` identical in Task 2 test and the Task 2 Step 3 rewrite; `EdgeIconButton(systemImage:accessibilityLabel:action:)` matches the confirmed initializer; `GearStoreScreen(gearStore:)` matches the existing initializer. ✓
