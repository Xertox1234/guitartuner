# LUMA — Gear Store: Seed Catalog + Discoverable Entry (iOS)

**Date:** 2026-06-21
**Status:** Approved
**Scope:** Seed the affiliate gear-store catalog and add a discoverable, at-rest-visible entry point on the iOS tuner screen.
**Builds on:** `docs/superpowers/specs/2026-06-14-monetization-design.md` (the shipped monetization v2)

---

## 1. Problem

The monetization v2 stack (accounts, saved tuning cards, email opt-in, affiliate gear store) is fully implemented and live. Two gaps make the affiliate store — the actual revenue driver — non-functional in practice:

1. **The catalog is empty.** `GET /store/products` is live and returns `200`, but the `store_products` D1 table was never seeded (the only migration just creates empty tables; there is no seed file). Production returns `{"products":[]}`.
2. **The store is undiscoverable.** Even once populated, the only entry point is a small "Store" bag icon inside the **expanded** bottom drawer — invisible at rest, reachable only after a swipe-up gesture. The product owner confirmed it is "not very visible at all."

A discoverable empty store earns nothing, so seeding is the lead item; the entry point makes the now-populated store reachable.

## 2. Approach (decisions locked)

| Decision | Choice |
|---|---|
| Catalog | Seed a realistic **starter catalog now with template Sweetwater URLs**; swap real affiliate links before App Store launch. |
| Entry point | **Top-chrome bag icon** on the iOS tuner screen (most discoverable; clean split — shop in chrome, tunings in drawer). A conscious, owner-approved deviation from the spec §1 "tuner is the hero / all commerce behind the drawer" principle. |
| Old drawer "Store" button | **Kept** — harmless redundancy; the top-chrome icon becomes the primary path. |
| Platform | **iOS only** this round. |

## 3. Part 1 — Seed the catalog (backend: `workers/luma-api`)

### 3.1 Seed file
- **New file:** `workers/luma-api/seed/store_products.sql`
- **Idempotent:** `INSERT OR REPLACE INTO store_products (...)` with **stable string IDs** (e.g. `prod-elixir-nanoweb-light`) so the file is safely re-runnable without duplicating rows.
- Columns match the schema in `migrations/0001_initial.sql`:
  `id, category, name, description, price_hint, sweetwater_url, image_url, is_featured, sort_order`.
- `image_url` left `''` (the iOS `ProductCard`/`FeaturedBanner` render category SF Symbols, not remote images — no image hosting needed for v1).

### 3.2 Template URL convention
Each `sweetwater_url` is a **Sweetwater search URL** for the product, e.g.
`https://www.sweetwater.com/store/search?s=Elixir+Nanoweb+Light+Electric`.
Rationale: search URLs reliably resolve to a real page today (so the end-to-end tap-through is genuinely testable), carry no affiliate ID, and are trivially swapped for affiliate-wrapped product URLs before launch. A header comment in the seed file marks this as the pre-launch swap point.

**Re-seed clobber warning:** because the seed uses `INSERT OR REPLACE` with stable IDs, the real-affiliate-link swap must be done by **editing `seed/store_products.sql` and re-applying it** — never by hand-editing URLs directly in production D1, which a later re-seed would silently overwrite back to the template. This is called out in the seed file header.

### 3.3 Starter catalog (~12 products, 2 featured)

| category | name | price_hint | featured |
|---|---|---|---|
| strings | Elixir Nanoweb Electric, Light (.010–.046) | ~$13 | ★ |
| strings | D'Addario EXL110 Nickel Wound | ~$6 | |
| strings | Ernie Ball Regular Slinky | ~$6 | |
| strings | Elixir Nanoweb Bass, 4-String Light | ~$30 | |
| strings | D'Addario EXL170 Bass | ~$22 | |
| tuners | Snark ST-2 Clip-On Tuner | ~$15 | ★ |
| tuners | TC Electronic PolyTune Clip | ~$49 | |
| tuners | Boss TU-3 Chromatic Tuner Pedal | ~$105 | |
| picks | Dunlop Tortex Standard .60mm (72-pack) | ~$22 | |
| picks | Fender 351 Celluloid Picks (12-pack) | ~$5 | |
| guitars | Fender Player II Stratocaster | ~$799 | |
| basses | Fender Player II Precision Bass | ~$849 | |

`sort_order` ascending within the natural reading order above; the route already sorts `is_featured DESC, sort_order ASC`. Exact copy/descriptions finalized in the implementation plan.

### 3.4 Apply + verify
- Local parity: `wrangler d1 execute luma --local --file=seed/store_products.sql`.
- Production: `wrangler d1 execute luma --remote --file=seed/store_products.sql` — **a live, outward-facing write; performed only with explicit go-ahead at execution time.**
- Verify: `curl https://luma-api.william-tower.workers.dev/store/products` returns a non-empty `products` array with the seeded rows.

## 4. Part 2 — Discoverable entry point (iOS: `App/LiveTunerScreen.swift`)

- Add `@State private var showGearStore = false`.
- Add a **bag `EdgeIconButton`** to the `topChrome` right-hand `HStack` (beside `EdgeIconButton` Stage Mode and `SettingsButton`):
  ```swift
  EdgeIconButton(systemImage: "bag", accessibilityLabel: "Gear Store") { showGearStore = true }
  ```
- Add `.fullScreenCover(isPresented: $showGearStore) { GearStoreScreen(gearStore: gearStore) }` to the body.
- **Gating:** the bag button and the `.fullScreenCover` are wrapped `#if os(iOS)` (matches `GearStoreScreen`/`fullScreenCover` availability; keeps macOS out of scope cleanly).
- The existing drawer "Store" button in `BottomDrawer.header` is **unchanged**.

No new types, no package-boundary changes; `gearStore` is already a `LiveTunerScreen` property threaded from `LumaApp`.

**Presentation-conflict risk (verify early).** `LiveTunerScreen` already presents the drawer as a *permanently-open* sheet (`.sheet(isPresented: .constant(true))`). Adding a `.fullScreenCover` on the **same base view** means the base presents a sheet and a cover simultaneously — the classic "attempt to present while already presenting" combination. The existing drawer "Store" button avoids this by presenting its cover from *within* the sheet. This must be verified on a real iOS run as an early step. **Fallback if it conflicts:** route the bag tap through the drawer's existing `showGearStore` presentation (e.g. via a shared binding) instead of a second base-level cover, or hoist the cover above the sheet. The type surface is trivial; the presentation interaction is the actual risk.

## 5. Data flow (contract unchanged)

```
Tap top-chrome bag → GearStoreScreen
  → GET /store/products (now non-empty; edge cache 1h + local JSON cache fallback)
  → category pills filter; featured banner for is_featured rows
  → tap product → openURL(sweetwater_url) → Safari
```

## 6. Error / empty handling

Unchanged from the shipped `GearStoreModel` / `GearStoreScreen`:
- Fetch fails with non-empty cache → serve stale silently.
- Fetch fails with empty cache → `ContentUnavailableView` ("Unable to load products").
- After seeding, the normal path shows the populated grid. The affiliate-disclosure footer remains always visible.

## 7. Privacy & compliance

No change to the privacy posture: zero tracking SDK, audio still never leaves the device, affiliate disclosure footer present. Template URLs carry no affiliate ID; the pre-launch swap introduces the affiliate ID only.

## 8. Testing / verification (ordered — early gates first)

The store has **never decoded a real row** (it has always been empty), so the riskiest steps are the untested runtime seams, not document hygiene. The plan must run these as *early gates*, not a final glance.

**Gate A — Codable decode against real seeded data (BEFORE the production write).**
The D1→JSON→Swift seam is unexercised. Specific hazards:
- `is_featured` / `sort_order` are SQLite `INTEGER`, so `SELECT *` → `JSON.stringify` emits `"is_featured": 1` (a number), while `GearProduct.isFeatured` is a Swift `Bool`. Foundation's `JSONDecoder` may throw `typeMismatch` on `1`→`Bool`.
- `[GearProduct]` decodes **all-or-nothing** — one malformed/null row throws out the *entire* catalog, leaving the store still blank after all the work.
- snake_case `CodingKeys` mapping across all nine fields.

Action: apply the seed to **local** D1, capture the real `GET /store/products` payload, and run it through `JSONDecoder().decode(ProductsResponse.self, …)` in a Swift test asserting the full seeded count decodes. This single test closes Bool-coercion, all-or-nothing, and key-mapping at once. **If `1`→`Bool` throws, fix empirically** (tiny custom decode for `isFeatured`, or coerce in the route) and re-run before proceeding. This gate must pass before the `--remote` production seed.

**Gate B — Presentation interaction on a real iOS run (early).**
Verify the top-chrome bag opens `GearStoreScreen` *over* the permanently-open drawer without an "already presenting" conflict (see §4). If it conflicts, apply the §4 fallback before continuing.

**Then:**
- **Backend:** existing `test/store.test.ts` stays green; seed validity confirmed via the local apply in Gate A.
- **iOS:** `XcodeRefreshCodeIssuesInFile` on `LiveTunerScreen.swift` → clean; full build succeeds.
- **End-to-end (manual):** launch → bag visible in top chrome **at rest** (no gesture) → tap → seeded products render and category pills filter → tap a product → Safari opens the Sweetwater page.

## 9. Out of scope / open items

- **macOS store surface** — still iOS-gated; bringing the drawer/store to macOS (plus the `com.apple.security.network.client` entitlement) is tracked in `docs/todos/P3-macos-network-entitlement.md`.
- **Real affiliate links** — template URLs swapped for affiliate-wrapped URLs before App Store launch (Part 1 §3.2 marks the swap point).
- **StoreKit / IAP** — not planned (monetization spec §8).
- **Remote product images** — deferred; SF Symbol placeholders are sufficient for v1.
