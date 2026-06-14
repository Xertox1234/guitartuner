import { beforeAll, vi } from 'vitest'
import { env, applyD1Migrations } from 'cloudflare:test'

// Intercept all Resend API calls so tests never make real HTTP requests.
// This also ensures sendVerificationEmail's res.ok check doesn't throw.
const originalFetch = globalThis.fetch
globalThis.fetch = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
  const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url
  if (url.startsWith('https://api.resend.com')) {
    return new Response(JSON.stringify({ id: 'test' }), { status: 200 })
  }
  return originalFetch(input, init)
}) as typeof fetch

const migrations = [
  {
    name: '0001_initial',
    queries: [
      `CREATE TABLE IF NOT EXISTS users (
        id               TEXT PRIMARY KEY,
        email            TEXT UNIQUE,
        apple_sub        TEXT UNIQUE,
        password_hash    TEXT,
        verified         INTEGER NOT NULL DEFAULT 0,
        marketing_opt_in INTEGER NOT NULL DEFAULT 0,
        created_at       TEXT NOT NULL DEFAULT (datetime('now'))
      )`,
      `CREATE TABLE IF NOT EXISTS tuning_cards (
        id           TEXT PRIMARY KEY,
        user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name         TEXT NOT NULL,
        notes        TEXT NOT NULL DEFAULT '',
        instrument   TEXT NOT NULL,
        a4           REAL NOT NULL,
        palette      TEXT NOT NULL,
        strings_json TEXT NOT NULL,
        created_at   TEXT NOT NULL DEFAULT (datetime('now'))
      )`,
      `CREATE TABLE IF NOT EXISTS store_products (
        id             TEXT PRIMARY KEY,
        category       TEXT NOT NULL,
        name           TEXT NOT NULL,
        description    TEXT NOT NULL DEFAULT '',
        price_hint     TEXT NOT NULL DEFAULT '',
        sweetwater_url TEXT NOT NULL,
        image_url      TEXT NOT NULL DEFAULT '',
        is_featured    INTEGER NOT NULL DEFAULT 0,
        sort_order     INTEGER NOT NULL DEFAULT 0
      )`,
    ],
  },
]

beforeAll(async () => {
  await applyD1Migrations(env.DB, migrations)
})
