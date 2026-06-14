# LUMA v2 — Monetization Design Spec

**Date:** 2026-06-14  
**Status:** Approved  
**Scope:** Optional account registration, saved tuning cards, email affiliate opt-in, affiliate gear store

---

## 1. Overview

LUMA v2 adds three co-dependent monetization features on top of the privacy-first v1 foundation:

1. **Saved Tuning Cards** — registered users can snapshot their full tuner state (instrument, custom strings, A4 calibration, strobe palette, notes) into named cards that load with one tap.
2. **Email Affiliate Opt-in** — strictly optional, unchecked-by-default consent to receive gear deals and app news via Resend.
3. **Affiliate Gear Store** — a dynamic, Cloudflare-served product catalogue that opens Sweetwater in Safari. No tracking SDK in LUMA.

The tuner remains the cold-open face of the app. All new surfaces are behind a swipe-up bottom drawer — no tab bar, no navigation restructuring.

---

## 2. Architecture

### 2.1 Package / layer boundaries (unchanged)

```
TunerEngine       — DSP + capture, no UI, no networking
LumaDesignSystem  — design tokens + strobe, no DSP
App/              — glue layer; owns auth, cards, store
```

All networking lives exclusively in the `App/` layer. `TunerEngine` and `LumaDesignSystem` remain networking-free.

### 2.2 New App-layer components

| Component | Type | Responsibility |
|---|---|---|
| `AccountModel` | `@MainActor @Observable` | Auth state, JWT storage in Keychain, Sign in with Apple + email flows |
| `TuningCardStore` | `@MainActor @Observable` | Fetch/save/delete cards via API; local cache (JSON in App Support) |
| `GearStoreModel` | `@MainActor @Observable` | Fetch product list; edge + local cache |
| `LumaAPI` | `actor` | Isolated URLSession wrapper — the single networking actor in the app |
| `BottomDrawer` | SwiftUI view | Three-state sheet (peeked / half-open / full); hosts card grid + store entry |
| `AccountSheet` | SwiftUI view | Registration / sign-in flow (Sign in with Apple + email + password) |
| `SaveCardSheet` | SwiftUI view | Name + notes form; shows live snapshot of settings being captured |
| `GearStoreScreen` | SwiftUI view | Full-screen modal; category pills + product grid; opens Sweetwater via `openURL` |

### 2.3 Cloudflare backend

**Workers:** A single Cloudflare Worker handles all API routes. No Railway involvement for the API (Railway is available for a future admin dashboard if needed).

**D1 schema:**

```sql
-- Users
CREATE TABLE users (
  id          TEXT PRIMARY KEY,       -- UUID
  email       TEXT UNIQUE,            -- null for Apple-only users
  apple_sub   TEXT UNIQUE,            -- null for email-only users
  password_hash TEXT,                 -- null for Apple-only users
  verified    INTEGER DEFAULT 0,      -- 1 = email verified
  marketing_opt_in INTEGER DEFAULT 0, -- explicit consent flag
  created_at  TEXT DEFAULT (datetime('now'))
);

-- Tuning cards
CREATE TABLE tuning_cards (
  id          TEXT PRIMARY KEY,       -- UUID
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  notes       TEXT DEFAULT '',
  instrument  TEXT NOT NULL,          -- 'guitar' | 'bass'
  a4          REAL NOT NULL,          -- e.g. 440.0
  palette     TEXT NOT NULL,          -- LumaPalette raw value
  strings_json TEXT NOT NULL,         -- JSON array of {idx, midi, note, octave}
  created_at  TEXT DEFAULT (datetime('now'))
);

-- Affiliate store products
CREATE TABLE store_products (
  id            TEXT PRIMARY KEY,
  category      TEXT NOT NULL,        -- 'strings' | 'tuners' | 'guitars' | 'basses' | 'picks'
  name          TEXT NOT NULL,
  description   TEXT DEFAULT '',
  price_hint    TEXT DEFAULT '',      -- display string e.g. "~$7"
  sweetwater_url TEXT NOT NULL,       -- affiliate URL
  image_url     TEXT DEFAULT '',
  is_featured   INTEGER DEFAULT 0,
  sort_order    INTEGER DEFAULT 0
);
```

**API routes:**

| Method | Path | Auth | Notes |
|---|---|---|---|
| `POST` | `/auth/register` | None | Creates user, sends verification email via Resend |
| `POST` | `/auth/verify` | None | Consumes email token, marks verified |
| `POST` | `/auth/login` | None | Returns JWT |
| `POST` | `/auth/apple` | None | Exchanges Apple identity token, returns JWT |
| `GET` | `/tunings` | Bearer JWT | Returns user's cards |
| `POST` | `/tunings` | Bearer JWT | Creates a card |
| `DELETE` | `/tunings/:id` | Bearer JWT | Deletes a card |
| `POST` | `/email/subscribe` | Bearer JWT | Opts user into marketing list in Resend |
| `POST` | `/email/unsubscribe` | Bearer JWT | Removes from Resend marketing list |
| `GET` | `/store/products` | None | Public; cached at edge 1-hour TTL |
| `POST` | `/auth/refresh` | Bearer JWT (expired ok) | Issues a new JWT; old token must be ≤7 days past expiry |

**Auth mechanism:** JWT (HS256, 30-day expiry). Stored in iOS Keychain via `Security` framework. On 401, `LumaAPI` silently calls `/auth/refresh`; if that also fails, clears Keychain and prompts re-login.

**Email:** Resend handles both transactional (verification, welcome) and marketing (gear deals). Single API key, two audiences (transactional vs. marketing list).

---

## 3. UI / Navigation

### 3.1 Bottom drawer

The drawer is a persistent `UISheetPresentationController` (iOS) / `.sheet` with custom detents (macOS uses a slide-over panel). Three detent states:

| State | Height | Content |
|---|---|---|
| **Peeked** | ~80 pt | Drag handle + horizontal scroll of card chips + "+" slot |
| **Half-open** | ~50% screen | Card grid (2-col) + "Save Current" CTA + "Store" button + sign-in nudge if unauthenticated |
| **Full** | ~90% screen | Account management (name, email, change password, marketing opt-in toggle, sign out) |

The tuner screen is never obscured in the peeked state. Tapping the strobe collapses the drawer back to peeked.

### 3.2 Registration / sign-in flow

Triggered by tapping "+ Save Current" without an active session.

**Screen 1 — Auth gate:**
- Sign in with Apple button (top)
- Divider
- Email + password fields
- "Create Account" primary CTA
- "Already have an account? Sign in" toggle

**Screen 2 — Email opt-in** *(email/password signup only; Apple skips directly to Screen 3)*:
- "Check your inbox" copy with the user's email shown
- Opt-in checkbox, **unchecked by default**: "Get exclusive gear deals — occasional emails with handpicked Sweetwater deals. No spam. Unsubscribe anytime."
- "Continue" primary CTA / "I'll skip for now" secondary

**Screen 3 — Save card:**
- Name field (pre-filled with current tuning preset label if a named preset is active)
- Optional notes field
- Read-only snapshot preview: instrument, tuning, A4, palette
- **Apple users only:** opt-in checkbox (unchecked) + helper text: "Share your real email to receive gear deals — Apple keeps your address private by default."
- "Save Card" CTA

After first auth, "+ Save Current" goes directly to Screen 3.

**Apple-specific:** Apple's private relay email is stored as the user's address; `apple_sub` is the primary identity key. Apple users see the gear deal opt-in on Screen 3 instead of Screen 2, with the option to enter their real email address for marketing.

### 3.3 Gear store screen

Full-screen modal (`.fullScreenCover` on iOS). Pushed from the "Store" button in the half-open drawer.

- Navigation bar: close ("✕") + title "GEAR SHOP"
- Category pills (horizontal scroll): All · Strings · Tuners · Guitars · Basses · Picks
- Featured banner (is_featured = 1 products)
- 2-column product grid: name, category, price_hint, "Shop →" button
- Tapping any product: `openURL(sweetwater_url)` — opens Safari, no in-app browser
- Affiliate disclosure footer: visible at all times
- Offline: last-fetched product list shown from local cache; no error state for stale content

---

## 4. Privacy & compliance

| Concern | Decision |
|---|---|
| Audio data | Never leaves device. Unchanged from v1. |
| Tuning card data | Stored server-side only for registered users who explicitly saved. |
| Email | Collected only with explicit opt-in (unchecked default). Double opt-in via email verification. |
| Affiliate tracking | Zero tracking SDK in LUMA. Sweetwater logs their own referral click. |
| Apple privacy label update | v2 adds: *Contact Info → Email, used for app functionality and (if opted in) marketing.* |
| GDPR / CAN-SPAM / CASL | Explicit informed consent, easy unsubscribe, no pre-checked boxes, privacy policy linked at signup. |
| JWT storage | iOS Keychain only — never `UserDefaults`, never iCloud. |

---

## 5. Data flow

```
User taps "+ Save Current" (unauthenticated)
  → AccountSheet presented
  → Sign in with Apple / email+password
  → [email path] Resend sends verification email
  → User verifies → JWT issued → Keychain
  → [opt-in checkbox] POST /email/subscribe → Resend marketing list
  → SaveCardSheet presented
  → POST /tunings → D1 tuning_cards
  → Card appears in drawer (peeked state)

User taps a card
  → LiveTunerModel.setInstrument() + setTuning() + a4 + palette restored
  → Tuner immediately active with saved settings

User opens Store
  → GearStoreScreen presented
  → GET /store/products (cached at edge; local cache fallback)
  → User taps product → openURL(sweetwater_url) → Safari
```

---

## 6. Error handling

| Scenario | Behaviour |
|---|---|
| Network unavailable on card save | Show inline error; local draft preserved so user can retry |
| JWT expired on card fetch | Silent refresh attempt; if fails, prompt re-login |
| Store products fetch fails | Show cached products; no error UI if cache exists; "Unable to load" only if no cache |
| Apple Sign In cancelled | Dismiss sheet, no state change |
| Email already registered | Inline field error: "An account with this email exists — sign in instead" |
| Verification email not received | "Resend email" link after 60 seconds |

---

## 7. Testing strategy

- `AccountModel` — unit-test JWT decode/expiry, Keychain read/write (mock Keychain in tests)
- `LumaAPI` — test against a local Worker dev instance (`wrangler dev`); no mocking of network layer
- `TuningCardStore` — test round-trip: save card → fetch → restore into `LiveTunerModel`
- `GearStoreModel` — test cache logic: fresh fetch, stale cache serve, offline fallback
- `BottomDrawer` detent states — SwiftUI preview per state; no automated test needed
- Cloudflare Worker — Vitest unit tests for each route handler; D1 migrations tested in CI with `wrangler d1 execute --local`

---

## 8. Out of scope (v2)

- Custom string pitch entry (users define notes manually) — v3
- Card sharing between users — v3
- Push notifications for gear deals — v3
- In-app purchases / subscriptions — not planned
- Web dashboard for managing store products — deferred (Railway could host this later)
- Account linking (user registers with email then later wants to link Apple on same account) — v3; v2 treats email and Apple as separate accounts
