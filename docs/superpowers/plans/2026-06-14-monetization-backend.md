# LUMA v2 — Cloudflare Worker API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Cloudflare Worker + D1 backend powering saved tuning cards, account auth (email + Apple), email opt-in, and the dynamic affiliate store product API.

**Architecture:** A single Hono-based Cloudflare Worker handles all routes, backed by a D1 SQLite database. Auth uses HS256 JWTs (30-day expiry). Passwords use PBKDF2 via Web Crypto (no Node crypto). Apple Sign In tokens verified against Apple's JWKS. Transactional + marketing email via Resend REST API (no SDK).

**Tech Stack:** Cloudflare Workers, Hono 4.x, D1 (SQLite), Resend API, Web Crypto API, Wrangler 3.x, Vitest + @cloudflare/vitest-pool-workers, TypeScript

**Spec:** `docs/superpowers/specs/2026-06-14-monetization-design.md`
**iOS plan:** `docs/superpowers/plans/2026-06-14-monetization-ios.md` (implement after this)

---

## File Map

```
workers/luma-api/
├── src/
│   ├── index.ts           # Hono app + route registration
│   ├── types.ts           # Env bindings, error helpers, shared row types
│   ├── utils.ts           # randomUUID
│   ├── jwt.ts             # HS256 sign / verify / verifyExpired (Web Crypto)
│   ├── password.ts        # PBKDF2 hash / verify (Web Crypto)
│   ├── apple.ts           # RS256 Apple identity token validation (JWKS)
│   ├── resend.ts          # Resend email + marketing list (fetch, no SDK)
│   ├── auth.ts            # /auth/* handlers
│   ├── tunings.ts         # /tunings handlers
│   ├── store.ts           # /store/products handler
│   └── email.ts           # /email/subscribe + /email/unsubscribe handlers
├── migrations/
│   └── 0001_initial.sql
├── test/
│   ├── helpers.ts         # In-test D1 seed helpers
│   ├── jwt.test.ts
│   ├── password.test.ts
│   ├── auth.test.ts
│   ├── tunings.test.ts
│   └── store.test.ts
├── wrangler.toml
├── package.json
└── tsconfig.json
```

---

### Task 1: Scaffold the Worker project

**Files:**
- Create: `workers/luma-api/package.json`
- Create: `workers/luma-api/tsconfig.json`
- Create: `workers/luma-api/wrangler.toml`
- Create: `workers/luma-api/vitest.config.ts`

- [ ] **Step 1: Create `workers/luma-api/package.json`**

```json
{
  "name": "luma-api",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "hono": "^4.4.0"
  },
  "devDependencies": {
    "@cloudflare/vitest-pool-workers": "^0.5.0",
    "@cloudflare/workers-types": "^4.20240725.0",
    "typescript": "^5.5.0",
    "vitest": "^1.6.0",
    "wrangler": "^3.65.0"
  }
}
```

- [ ] **Step 2: Create `workers/luma-api/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "lib": ["ES2022"],
    "types": ["@cloudflare/workers-types"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

- [ ] **Step 3: Create `workers/luma-api/wrangler.toml`**

```toml
name = "luma-api"
main = "src/index.ts"
compatibility_date = "2024-07-25"
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "luma"
database_id = "REPLACE_AFTER_wrangler_d1_create"

[vars]
APPLE_BUNDLE_ID = "com.luma.tuner"

# Secrets (set via `wrangler secret put`):
# JWT_SECRET
# RESEND_API_KEY
# RESEND_AUDIENCE_ID
```

- [ ] **Step 4: Create `workers/luma-api/vitest.config.ts`**

```typescript
import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config'

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          bindings: {
            JWT_SECRET: 'test-secret-32-chars-minimum-ok',
            RESEND_API_KEY: 're_test_key',
            RESEND_AUDIENCE_ID: 'test-audience-id',
            APPLE_BUNDLE_ID: 'com.luma.tuner',
          },
        },
      },
    },
  },
})
```

- [ ] **Step 5: Install dependencies and verify TypeScript compiles**

```bash
cd workers/luma-api && npm install
```

Expected: `node_modules/` populated, no errors.

- [ ] **Step 6: Commit**

```bash
git add workers/luma-api/package.json workers/luma-api/tsconfig.json workers/luma-api/wrangler.toml workers/luma-api/vitest.config.ts workers/luma-api/package-lock.json
git commit -m "feat(backend): scaffold Cloudflare Worker project"
```

---

### Task 2: D1 migration + `types.ts` + `utils.ts`

**Files:**
- Create: `workers/luma-api/migrations/0001_initial.sql`
- Create: `workers/luma-api/src/types.ts`
- Create: `workers/luma-api/src/utils.ts`

- [ ] **Step 1: Create `workers/luma-api/migrations/0001_initial.sql`**

```sql
CREATE TABLE IF NOT EXISTS users (
  id               TEXT PRIMARY KEY,
  email            TEXT UNIQUE,
  apple_sub        TEXT UNIQUE,
  password_hash    TEXT,
  verified         INTEGER NOT NULL DEFAULT 0,
  marketing_opt_in INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS tuning_cards (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  notes        TEXT NOT NULL DEFAULT '',
  instrument   TEXT NOT NULL,
  a4           REAL NOT NULL,
  palette      TEXT NOT NULL,
  strings_json TEXT NOT NULL,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS store_products (
  id             TEXT PRIMARY KEY,
  category       TEXT NOT NULL,
  name           TEXT NOT NULL,
  description    TEXT NOT NULL DEFAULT '',
  price_hint     TEXT NOT NULL DEFAULT '',
  sweetwater_url TEXT NOT NULL,
  image_url      TEXT NOT NULL DEFAULT '',
  is_featured    INTEGER NOT NULL DEFAULT 0,
  sort_order     INTEGER NOT NULL DEFAULT 0
);
```

- [ ] **Step 2: Create `workers/luma-api/src/types.ts`**

```typescript
export interface Env {
  DB: D1Database
  JWT_SECRET: string
  RESEND_API_KEY: string
  RESEND_AUDIENCE_ID: string
  APPLE_BUNDLE_ID: string
}

export interface UserRow {
  id: string
  email: string | null
  apple_sub: string | null
  password_hash: string | null
  verified: number
  marketing_opt_in: number
  created_at: string
}

export interface TuningCardRow {
  id: string
  user_id: string
  name: string
  notes: string
  instrument: string
  a4: number
  palette: string
  strings_json: string
  created_at: string
}

export interface StoreProductRow {
  id: string
  category: string
  name: string
  description: string
  price_hint: string
  sweetwater_url: string
  image_url: string
  is_featured: number
  sort_order: number
}

export function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status })
}

export function jsonOk(data: unknown, headers?: HeadersInit): Response {
  return Response.json(data, { headers })
}
```

- [ ] **Step 3: Create `workers/luma-api/src/utils.ts`**

```typescript
export function randomUUID(): string {
  return crypto.randomUUID()
}
```

- [ ] **Step 4: Apply migration to local D1**

First create the D1 database (once):
```bash
cd workers/luma-api && npx wrangler d1 create luma
```
Copy the `database_id` from the output into `wrangler.toml`.

Then apply the migration locally:
```bash
npx wrangler d1 migrations apply luma --local
```

Expected: `✅ Migration 0001_initial applied`

- [ ] **Step 5: Commit**

```bash
git add workers/luma-api/migrations/ workers/luma-api/src/types.ts workers/luma-api/src/utils.ts workers/luma-api/wrangler.toml
git commit -m "feat(backend): D1 schema + types + utils"
```

---

### Task 3: JWT utilities

**Files:**
- Create: `workers/luma-api/src/jwt.ts`
- Create: `workers/luma-api/test/jwt.test.ts`

- [ ] **Step 1: Write the failing tests**

Create `workers/luma-api/test/jwt.test.ts`:

```typescript
import { describe, it, expect } from 'vitest'
import { sign, verify, verifyExpired, makePayload } from '../src/jwt'

const SECRET = 'test-secret-32-chars-minimum-ok'

describe('jwt', () => {
  it('signs and verifies a payload', async () => {
    const payload = makePayload('user-123')
    const token = await sign(payload, SECRET)
    expect(token.split('.').length).toBe(3)
    const decoded = await verify(token, SECRET)
    expect(decoded.sub).toBe('user-123')
  })

  it('rejects tampered tokens', async () => {
    const token = await sign(makePayload('user-123'), SECRET)
    const parts = token.split('.')
    const tampered = `${parts[0]}.${parts[1]}.invalidsig`
    await expect(verify(tampered, SECRET)).rejects.toThrow('Invalid JWT signature')
  })

  it('rejects expired tokens', async () => {
    const expired = { sub: 'u', iat: 0, exp: 1 }
    const token = await sign(expired, SECRET)
    await expect(verify(token, SECRET)).rejects.toThrow('JWT expired')
  })

  it('verifyExpired accepts tokens within 7-day grace window', async () => {
    const sixDaysAgo = Math.floor(Date.now() / 1000) - 6 * 24 * 60 * 60
    const payload = { sub: 'u', iat: sixDaysAgo - 86400, exp: sixDaysAgo }
    const token = await sign(payload, SECRET)
    const decoded = await verifyExpired(token, SECRET)
    expect(decoded.sub).toBe('u')
  })

  it('verifyExpired rejects tokens older than 7 days past expiry', async () => {
    const eightDaysAgo = Math.floor(Date.now() / 1000) - 8 * 24 * 60 * 60
    const payload = { sub: 'u', iat: eightDaysAgo - 86400, exp: eightDaysAgo }
    const token = await sign(payload, SECRET)
    await expect(verifyExpired(token, SECRET)).rejects.toThrow('JWT too old to refresh')
  })
})
```

- [ ] **Step 2: Run tests — expect failure**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "PASS|FAIL|Error"
```

Expected: `Cannot find module '../src/jwt'`

- [ ] **Step 3: Implement `workers/luma-api/src/jwt.ts`**

```typescript
export interface JWTPayload {
  sub: string
  iat: number
  exp: number
}

function b64url(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function decodeB64url(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(s.length + (4 - (s.length % 4)) % 4, '=')
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

async function hmacKey(secret: string, usage: KeyUsage): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, [usage]
  )
}

export function makePayload(userId: string): JWTPayload {
  const now = Math.floor(Date.now() / 1000)
  return { sub: userId, iat: now, exp: now + 30 * 24 * 60 * 60 }
}

export async function sign(payload: JWTPayload, secret: string): Promise<string> {
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })))
  const body = b64url(new TextEncoder().encode(JSON.stringify(payload)))
  const data = `${header}.${body}`
  const key = await hmacKey(secret, 'sign')
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data))
  return `${data}.${b64url(sig)}`
}

export async function verify(token: string, secret: string): Promise<JWTPayload> {
  const payload = await verifySignature(token, secret)
  if (payload.exp < Math.floor(Date.now() / 1000)) throw new Error('JWT expired')
  return payload
}

export async function verifyExpired(token: string, secret: string): Promise<JWTPayload> {
  const payload = await verifySignature(token, secret)
  const graceCutoff = Math.floor(Date.now() / 1000) - 7 * 24 * 60 * 60
  if (payload.exp < graceCutoff) throw new Error('JWT too old to refresh')
  return payload
}

async function verifySignature(token: string, secret: string): Promise<JWTPayload> {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('Invalid JWT format')
  const [header, body, sig] = parts
  const key = await hmacKey(secret, 'verify')
  const valid = await crypto.subtle.verify(
    'HMAC', key, decodeB64url(sig),
    new TextEncoder().encode(`${header}.${body}`)
  )
  if (!valid) throw new Error('Invalid JWT signature')
  return JSON.parse(new TextDecoder().decode(decodeB64url(body))) as JWTPayload
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "✓|✗|PASS|FAIL"
```

Expected: 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add workers/luma-api/src/jwt.ts workers/luma-api/test/jwt.test.ts
git commit -m "feat(backend): JWT sign/verify/refresh utilities"
```

---

### Task 4: Password hashing utilities

**Files:**
- Create: `workers/luma-api/src/password.ts`
- Create: `workers/luma-api/test/password.test.ts`

- [ ] **Step 1: Write the failing tests**

Create `workers/luma-api/test/password.test.ts`:

```typescript
import { describe, it, expect } from 'vitest'
import { hashPassword, verifyPassword } from '../src/password'

describe('password', () => {
  it('hashes a password and verifies it correctly', async () => {
    const hash = await hashPassword('hunter2')
    expect(hash).toContain(':')
    expect(await verifyPassword('hunter2', hash)).toBe(true)
  })

  it('rejects wrong passwords', async () => {
    const hash = await hashPassword('hunter2')
    expect(await verifyPassword('hunter3', hash)).toBe(false)
  })

  it('produces different hashes for same password (random salt)', async () => {
    const h1 = await hashPassword('password')
    const h2 = await hashPassword('password')
    expect(h1).not.toBe(h2)
  })
})
```

- [ ] **Step 2: Run tests — expect failure**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "PASS|FAIL|Error"
```

Expected: `Cannot find module '../src/password'`

- [ ] **Step 3: Implement `workers/luma-api/src/password.ts`**

```typescript
export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16))
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits']
  )
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' }, key, 256
  )
  const saltB64 = btoa(String.fromCharCode(...salt))
  const hashB64 = btoa(String.fromCharCode(...new Uint8Array(bits)))
  return `${saltB64}:${hashB64}`
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const colonIdx = stored.indexOf(':')
  if (colonIdx === -1) return false
  const saltB64 = stored.slice(0, colonIdx)
  const hashB64 = stored.slice(colonIdx + 1)
  const salt = Uint8Array.from(atob(saltB64), c => c.charCodeAt(0))
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits']
  )
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' }, key, 256
  )
  const computed = btoa(String.fromCharCode(...new Uint8Array(bits)))
  return computed === hashB64
}
```

- [ ] **Step 4: Run all tests — expect all pass**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "✓|✗|PASS|FAIL"
```

Expected: 8 tests pass (5 JWT + 3 password).

- [ ] **Step 5: Commit**

```bash
git add workers/luma-api/src/password.ts workers/luma-api/test/password.test.ts
git commit -m "feat(backend): PBKDF2 password hash/verify"
```

---

### Task 5: Resend client + Apple token validation

**Files:**
- Create: `workers/luma-api/src/resend.ts`
- Create: `workers/luma-api/src/apple.ts`

No unit tests for these — Resend makes real HTTP calls (test in integration), and Apple JWKS validation requires network access to `appleid.apple.com` (tested manually with a real device token).

- [ ] **Step 1: Create `workers/luma-api/src/resend.ts`**

```typescript
const RESEND = 'https://api.resend.com'

export async function sendVerificationEmail(
  to: string,
  verifyToken: string,
  apiKey: string
): Promise<void> {
  const deepLink = `lumatuner://verify?token=${encodeURIComponent(verifyToken)}`
  await fetch(`${RESEND}/emails`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: 'LUMA <noreply@mail.lumatuner.com>',
      to,
      subject: 'Verify your LUMA account',
      html: `<p>Tap to verify: <a href="${deepLink}">Verify Email</a></p><p>Token: <code>${verifyToken}</code></p>`,
    }),
  })
}

export async function subscribeToMarketing(
  email: string,
  audienceId: string,
  apiKey: string
): Promise<void> {
  await fetch(`${RESEND}/audiences/${audienceId}/contacts`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, unsubscribed: false }),
  })
}

export async function unsubscribeFromMarketing(
  email: string,
  audienceId: string,
  apiKey: string
): Promise<void> {
  await fetch(`${RESEND}/audiences/${audienceId}/contacts`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, unsubscribed: true }),
  })
}
```

- [ ] **Step 2: Create `workers/luma-api/src/apple.ts`**

```typescript
interface AppleJWK {
  kty: string; kid: string; use: string; alg: string; n: string; e: string
}

let jwksCache: { keys: AppleJWK[]; at: number } | null = null

async function getAppleKeys(): Promise<AppleJWK[]> {
  if (jwksCache && Date.now() - jwksCache.at < 3_600_000) return jwksCache.keys
  const r = await fetch('https://appleid.apple.com/auth/keys')
  const { keys } = await r.json<{ keys: AppleJWK[] }>()
  jwksCache = { keys, at: Date.now() }
  return keys
}

function decodeB64url(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(s.length + (4 - (s.length % 4)) % 4, '=')
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

interface ApplePayload {
  iss: string; aud: string; sub: string; exp: number
}

/**
 * Validates an Apple identity token and returns the Apple user ID (`sub`).
 * Returns null if invalid. Throws on network errors.
 */
export async function validateAppleToken(
  token: string,
  bundleId: string
): Promise<string | null> {
  const parts = token.split('.')
  if (parts.length !== 3) return null

  let header: { kid: string; alg: string }
  let payload: ApplePayload
  try {
    header = JSON.parse(new TextDecoder().decode(decodeB64url(parts[0])))
    payload = JSON.parse(new TextDecoder().decode(decodeB64url(parts[1])))
  } catch {
    return null
  }

  if (payload.iss !== 'https://appleid.apple.com') return null
  if (payload.aud !== bundleId) return null
  if (payload.exp < Math.floor(Date.now() / 1000)) return null

  const keys = await getAppleKeys()
  const jwk = keys.find(k => k.kid === header.kid)
  if (!jwk) return null

  const key = await crypto.subtle.importKey(
    'jwk',
    { kty: 'RSA', n: jwk.n, e: jwk.e, alg: 'RS256', use: 'sig' } as JsonWebKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['verify']
  )

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, decodeB64url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
  )
  return valid ? payload.sub : null
}
```

- [ ] **Step 3: Commit**

```bash
git add workers/luma-api/src/resend.ts workers/luma-api/src/apple.ts
git commit -m "feat(backend): Resend email client + Apple JWKS token validation"
```

---

### Task 6: Auth route handlers

**Files:**
- Create: `workers/luma-api/src/auth.ts`
- Create: `workers/luma-api/test/helpers.ts`
- Create: `workers/luma-api/test/auth.test.ts`

- [ ] **Step 1: Create `workers/luma-api/test/helpers.ts`**

```typescript
import type { Env } from '../src/types'

export async function seedUser(
  db: D1Database,
  overrides: Partial<{ id: string; email: string; password_hash: string; apple_sub: string; verified: number }>
) {
  const row = {
    id: overrides.id ?? 'user-seed-1',
    email: overrides.email ?? 'seed@example.com',
    password_hash: overrides.password_hash ?? null,
    apple_sub: overrides.apple_sub ?? null,
    verified: overrides.verified ?? 1,
  }
  await db.prepare(
    'INSERT OR REPLACE INTO users (id, email, password_hash, apple_sub, verified) VALUES (?, ?, ?, ?, ?)'
  ).bind(row.id, row.email, row.password_hash, row.apple_sub, row.verified).run()
  return row
}
```

- [ ] **Step 2: Write failing tests**

Create `workers/luma-api/test/auth.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { env, fetchMock } from 'cloudflare:test'
import worker from '../src/index'
import { hashPassword } from '../src/password'
import { seedUser } from './helpers'

// fetchMock intercepts outbound fetch (Resend calls) so tests don't make real HTTP
fetchMock.activate()
fetchMock.disableNetConnect()

describe('POST /auth/register', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM users')
    fetchMock.get('https://api.resend.com').intercept({ path: '/emails', method: 'POST' }).reply(200, '{}')
  })

  it('creates a user and returns 200', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'new@example.com', password: 'password123' }),
      }),
      env
    )
    expect(res.status).toBe(200)
    const body = await res.json<{ message: string }>()
    expect(body.message).toContain('Verification')
  })

  it('returns 409 if email already registered', async () => {
    await seedUser(env.DB, { email: 'dup@example.com' })
    const res = await worker.fetch(
      new Request('http://localhost/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'dup@example.com', password: 'password123' }),
      }),
      env
    )
    expect(res.status).toBe(409)
  })

  it('returns 400 for short password', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'x@example.com', password: 'short' }),
      }),
      env
    )
    expect(res.status).toBe(400)
  })
})

describe('POST /auth/login', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM users')
    const hash = await hashPassword('password123')
    await seedUser(env.DB, { email: 'login@example.com', password_hash: hash, verified: 1 })
  })

  it('returns JWT on valid credentials', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'login@example.com', password: 'password123' }),
      }),
      env
    )
    expect(res.status).toBe(200)
    const body = await res.json<{ token: string }>()
    expect(body.token.split('.').length).toBe(3)
  })

  it('returns 401 on wrong password', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'login@example.com', password: 'wrongpass' }),
      }),
      env
    )
    expect(res.status).toBe(401)
  })
})
```

- [ ] **Step 3: Run tests — expect failure**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "PASS|FAIL|Error" | head -5
```

Expected: `Cannot find module '../src/index'`

- [ ] **Step 4: Create `workers/luma-api/src/auth.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from './types'
import { jsonError, jsonOk } from './types'
import { sign, verify, verifyExpired, makePayload } from './jwt'
import { hashPassword, verifyPassword } from './password'
import { sendVerificationEmail } from './resend'
import { validateAppleToken } from './apple'
import { randomUUID } from './utils'

export const authRoutes = new Hono<{ Bindings: Env }>()

authRoutes.post('/register', async (c) => {
  const { email, password } = await c.req.json<{ email?: string; password?: string }>()
  if (!email || !password || password.length < 8) {
    return jsonError('Valid email and password (8+ chars) required', 400)
  }
  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first()
  if (existing) return jsonError('An account with this email exists — sign in instead', 409)

  const id = randomUUID()
  const hash = await hashPassword(password)
  await c.env.DB.prepare(
    'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)'
  ).bind(id, email, hash).run()

  // Verification token: short-lived JWT signed with a separate secret
  const verifyToken = await sign(
    { sub: id, iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600 },
    c.env.JWT_SECRET + ':verify'
  )
  await sendVerificationEmail(email, verifyToken, c.env.RESEND_API_KEY)
  return jsonOk({ message: 'Verification email sent. Check your inbox.' })
})

authRoutes.post('/verify', async (c) => {
  const { token } = await c.req.json<{ token?: string }>()
  if (!token) return jsonError('Token required', 400)
  try {
    const payload = await verify(token, c.env.JWT_SECRET + ':verify')
    await c.env.DB.prepare('UPDATE users SET verified = 1 WHERE id = ?').bind(payload.sub).run()
    const jwt = await sign(makePayload(payload.sub), c.env.JWT_SECRET)
    return jsonOk({ token: jwt })
  } catch {
    return jsonError('Invalid or expired verification token', 400)
  }
})

authRoutes.post('/login', async (c) => {
  const { email, password } = await c.req.json<{ email?: string; password?: string }>()
  if (!email || !password) return jsonError('Email and password required', 400)
  const user = await c.env.DB.prepare(
    'SELECT id, password_hash, verified FROM users WHERE email = ?'
  ).bind(email).first<{ id: string; password_hash: string | null; verified: number }>()
  if (!user || !user.password_hash) return jsonError('Invalid credentials', 401)
  const ok = await verifyPassword(password, user.password_hash)
  if (!ok) return jsonError('Invalid credentials', 401)
  if (!user.verified) return jsonError('Please verify your email first', 403)
  const jwt = await sign(makePayload(user.id), c.env.JWT_SECRET)
  return jsonOk({ token: jwt })
})

authRoutes.post('/apple', async (c) => {
  const { identityToken } = await c.req.json<{ identityToken?: string }>()
  if (!identityToken) return jsonError('identityToken required', 400)
  const appleSub = await validateAppleToken(identityToken, c.env.APPLE_BUNDLE_ID)
  if (!appleSub) return jsonError('Invalid Apple identity token', 401)

  let user = await c.env.DB.prepare('SELECT id FROM users WHERE apple_sub = ?')
    .bind(appleSub).first<{ id: string }>()
  if (!user) {
    const id = randomUUID()
    await c.env.DB.prepare('INSERT INTO users (id, apple_sub, verified) VALUES (?, ?, 1)')
      .bind(id, appleSub).run()
    user = { id }
  }
  const jwt = await sign(makePayload(user.id), c.env.JWT_SECRET)
  return jsonOk({ token: jwt })
})

authRoutes.post('/refresh', async (c) => {
  const auth = c.req.header('Authorization')
  if (!auth?.startsWith('Bearer ')) return jsonError('Unauthorized', 401)
  try {
    const payload = await verifyExpired(auth.slice(7), c.env.JWT_SECRET)
    const jwt = await sign(makePayload(payload.sub), c.env.JWT_SECRET)
    return jsonOk({ token: jwt })
  } catch {
    return jsonError('Cannot refresh token', 401)
  }
})

export async function requireAuth(
  authHeader: string | null | undefined,
  jwtSecret: string
): Promise<string | null> {
  if (!authHeader?.startsWith('Bearer ')) return null
  try {
    const payload = await verify(authHeader.slice(7), jwtSecret)
    return payload.sub
  } catch {
    return null
  }
}
```

- [ ] **Step 5: Create `workers/luma-api/src/index.ts`** (minimal — will expand in Task 9)

```typescript
import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)

export default app
```

- [ ] **Step 6: Run tests — expect auth tests pass**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "✓|✗|PASS|FAIL"
```

Expected: 13 tests pass (5 JWT + 3 password + 5 auth).

- [ ] **Step 7: Commit**

```bash
git add workers/luma-api/src/auth.ts workers/luma-api/src/index.ts workers/luma-api/test/helpers.ts workers/luma-api/test/auth.test.ts
git commit -m "feat(backend): auth routes — register, verify, login, apple, refresh"
```

---

### Task 7: Tuning cards routes

**Files:**
- Create: `workers/luma-api/src/tunings.ts`
- Create: `workers/luma-api/test/tunings.test.ts`

- [ ] **Step 1: Write failing tests**

Create `workers/luma-api/test/tunings.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { env } from 'cloudflare:test'
import worker from '../src/index'
import { sign, makePayload } from '../src/jwt'
import { seedUser } from './helpers'

const SECRET = 'test-secret-32-chars-minimum-ok'

async function authHeader(userId: string) {
  const token = await sign(makePayload(userId), SECRET)
  return `Bearer ${token}`
}

const CARD_BODY = {
  name: 'Open G',
  notes: 'Good for slide',
  instrument: 'guitar',
  a4: 440,
  palette: 'aurora',
  strings_json: JSON.stringify([{ idx: 1, midi: 64, note: 'E', octave: 4 }]),
}

describe('/tunings', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM tuning_cards; DELETE FROM users')
    await seedUser(env.DB, { id: 'user-1' })
  })

  it('GET returns empty array for new user', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/tunings', {
        headers: { Authorization: await authHeader('user-1') },
      }),
      env
    )
    expect(res.status).toBe(200)
    const { cards } = await res.json<{ cards: unknown[] }>()
    expect(cards).toHaveLength(0)
  })

  it('POST saves a card and GET returns it', async () => {
    const post = await worker.fetch(
      new Request('http://localhost/tunings', {
        method: 'POST',
        headers: { Authorization: await authHeader('user-1'), 'Content-Type': 'application/json' },
        body: JSON.stringify(CARD_BODY),
      }),
      env
    )
    expect(post.status).toBe(200)

    const get = await worker.fetch(
      new Request('http://localhost/tunings', {
        headers: { Authorization: await authHeader('user-1') },
      }),
      env
    )
    const { cards } = await get.json<{ cards: { name: string }[] }>()
    expect(cards).toHaveLength(1)
    expect(cards[0].name).toBe('Open G')
  })

  it('DELETE removes a card', async () => {
    const { id } = await (await worker.fetch(
      new Request('http://localhost/tunings', {
        method: 'POST',
        headers: { Authorization: await authHeader('user-1'), 'Content-Type': 'application/json' },
        body: JSON.stringify(CARD_BODY),
      }),
      env
    )).json<{ id: string }>()

    const del = await worker.fetch(
      new Request(`http://localhost/tunings/${id}`, {
        method: 'DELETE',
        headers: { Authorization: await authHeader('user-1') },
      }),
      env
    )
    expect(del.status).toBe(200)

    const get = await worker.fetch(
      new Request('http://localhost/tunings', {
        headers: { Authorization: await authHeader('user-1') },
      }),
      env
    )
    const { cards } = await get.json<{ cards: unknown[] }>()
    expect(cards).toHaveLength(0)
  })

  it('returns 401 without auth', async () => {
    const res = await worker.fetch(new Request('http://localhost/tunings'), env)
    expect(res.status).toBe(401)
  })

  it('cannot delete another user card', async () => {
    await seedUser(env.DB, { id: 'user-2', email: 'u2@example.com' })
    const { id } = await (await worker.fetch(
      new Request('http://localhost/tunings', {
        method: 'POST',
        headers: { Authorization: await authHeader('user-1'), 'Content-Type': 'application/json' },
        body: JSON.stringify(CARD_BODY),
      }),
      env
    )).json<{ id: string }>()

    const del = await worker.fetch(
      new Request(`http://localhost/tunings/${id}`, {
        method: 'DELETE',
        headers: { Authorization: await authHeader('user-2') },
      }),
      env
    )
    expect(del.status).toBe(404)
  })
})
```

- [ ] **Step 2: Run tests — expect failure**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "tunings|FAIL" | head -5
```

Expected: tunings tests fail (no `/tunings` route yet).

- [ ] **Step 3: Create `workers/luma-api/src/tunings.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from './types'
import { jsonError, jsonOk } from './types'
import { requireAuth } from './auth'
import { randomUUID } from './utils'

export const tuningRoutes = new Hono<{ Bindings: Env }>()

tuningRoutes.get('/', async (c) => {
  const userId = await requireAuth(c.req.header('Authorization'), c.env.JWT_SECRET)
  if (!userId) return jsonError('Unauthorized', 401)
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM tuning_cards WHERE user_id = ? ORDER BY created_at DESC'
  ).bind(userId).all()
  return jsonOk({ cards: results })
})

tuningRoutes.post('/', async (c) => {
  const userId = await requireAuth(c.req.header('Authorization'), c.env.JWT_SECRET)
  if (!userId) return jsonError('Unauthorized', 401)
  const body = await c.req.json<{
    name?: string; notes?: string; instrument?: string;
    a4?: number; palette?: string; strings_json?: string
  }>()
  if (!body.name || !body.instrument || body.a4 == null || !body.strings_json || !body.palette) {
    return jsonError('Missing required fields: name, instrument, a4, palette, strings_json', 400)
  }
  const id = randomUUID()
  await c.env.DB.prepare(
    'INSERT INTO tuning_cards (id, user_id, name, notes, instrument, a4, palette, strings_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(id, userId, body.name, body.notes ?? '', body.instrument, body.a4, body.palette, body.strings_json).run()
  return jsonOk({ id })
})

tuningRoutes.delete('/:id', async (c) => {
  const userId = await requireAuth(c.req.header('Authorization'), c.env.JWT_SECRET)
  if (!userId) return jsonError('Unauthorized', 401)
  const cardId = c.req.param('id')
  const result = await c.env.DB.prepare(
    'DELETE FROM tuning_cards WHERE id = ? AND user_id = ?'
  ).bind(cardId, userId).run()
  if (result.meta.changes === 0) return jsonError('Not found', 404)
  return jsonOk({ deleted: true })
})
```

- [ ] **Step 4: Wire tuning routes in `workers/luma-api/src/index.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'
import { tuningRoutes } from './tunings'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)
app.route('/tunings', tuningRoutes)

export default app
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "✓|✗|PASS|FAIL"
```

Expected: 18 tests pass (5 + 3 + 5 + 5).

- [ ] **Step 6: Commit**

```bash
git add workers/luma-api/src/tunings.ts workers/luma-api/src/index.ts workers/luma-api/test/tunings.test.ts
git commit -m "feat(backend): tuning cards CRUD routes"
```

---

### Task 8: Store products + email routes, wire full router

**Files:**
- Create: `workers/luma-api/src/store.ts`
- Create: `workers/luma-api/src/email.ts`
- Modify: `workers/luma-api/src/index.ts`
- Create: `workers/luma-api/test/store.test.ts`

- [ ] **Step 1: Write failing store test**

Create `workers/luma-api/test/store.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { env } from 'cloudflare:test'
import worker from '../src/index'

describe('GET /store/products', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM store_products')
    await env.DB.prepare(
      'INSERT INTO store_products (id, category, name, sweetwater_url, is_featured, sort_order) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind('p1', 'strings', 'Ernie Ball Slinky', 'https://sweetwater.com/p1', 1, 0).run()
    await env.DB.prepare(
      'INSERT INTO store_products (id, category, name, sweetwater_url, is_featured, sort_order) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind('p2', 'picks', 'Dunlop Tortex', 'https://sweetwater.com/p2', 0, 1).run()
  })

  it('returns all products ordered featured-first', async () => {
    const res = await worker.fetch(new Request('http://localhost/store/products'), env)
    expect(res.status).toBe(200)
    const { products } = await res.json<{ products: { id: string; is_featured: number }[] }>()
    expect(products).toHaveLength(2)
    expect(products[0].id).toBe('p1')  // featured first
  })

  it('sets Cache-Control header', async () => {
    const res = await worker.fetch(new Request('http://localhost/store/products'), env)
    expect(res.headers.get('Cache-Control')).toContain('max-age=3600')
  })

  it('is public — no auth required', async () => {
    const res = await worker.fetch(new Request('http://localhost/store/products'), env)
    expect(res.status).toBe(200)
  })
})
```

- [ ] **Step 2: Create `workers/luma-api/src/store.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from './types'

export const storeRoutes = new Hono<{ Bindings: Env }>()

storeRoutes.get('/products', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM store_products ORDER BY is_featured DESC, sort_order ASC'
  ).all()
  return new Response(JSON.stringify({ products: results }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=3600, s-maxage=3600',
    },
  })
})
```

- [ ] **Step 3: Create `workers/luma-api/src/email.ts`**

```typescript
import { Hono } from 'hono'
import type { Env, UserRow } from './types'
import { jsonError, jsonOk } from './types'
import { requireAuth } from './auth'
import { subscribeToMarketing, unsubscribeFromMarketing } from './resend'

export const emailRoutes = new Hono<{ Bindings: Env }>()

emailRoutes.post('/subscribe', async (c) => {
  const userId = await requireAuth(c.req.header('Authorization'), c.env.JWT_SECRET)
  if (!userId) return jsonError('Unauthorized', 401)

  const user = await c.env.DB.prepare('SELECT id, email FROM users WHERE id = ?')
    .bind(userId).first<Pick<UserRow, 'id' | 'email'>>()
  if (!user) return jsonError('User not found', 404)

  const body = await c.req.json<{ email?: string }>().catch(() => ({}))
  const email = body.email ?? user.email
  if (!email) return jsonError('Email required (Apple users must provide real email for marketing)', 400)

  await c.env.DB.prepare('UPDATE users SET marketing_opt_in = 1 WHERE id = ?').bind(userId).run()
  await subscribeToMarketing(email, c.env.RESEND_AUDIENCE_ID, c.env.RESEND_API_KEY)
  return jsonOk({ subscribed: true })
})

emailRoutes.post('/unsubscribe', async (c) => {
  const userId = await requireAuth(c.req.header('Authorization'), c.env.JWT_SECRET)
  if (!userId) return jsonError('Unauthorized', 401)

  const user = await c.env.DB.prepare('SELECT id, email FROM users WHERE id = ?')
    .bind(userId).first<Pick<UserRow, 'id' | 'email'>>()
  if (!user || !user.email) return jsonError('No email on record', 400)

  await c.env.DB.prepare('UPDATE users SET marketing_opt_in = 0 WHERE id = ?').bind(userId).run()
  await unsubscribeFromMarketing(user.email, c.env.RESEND_AUDIENCE_ID, c.env.RESEND_API_KEY)
  return jsonOk({ unsubscribed: true })
})
```

- [ ] **Step 4: Wire all routes in `workers/luma-api/src/index.ts`**

```typescript
import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'
import { tuningRoutes } from './tunings'
import { storeRoutes } from './store'
import { emailRoutes } from './email'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)
app.route('/tunings', tuningRoutes)
app.route('/store', storeRoutes)
app.route('/email', emailRoutes)

export default app
```

- [ ] **Step 5: Run all tests — expect all pass**

```bash
cd workers/luma-api && npm test -- --reporter=verbose 2>&1 | grep -E "✓|✗|PASS|FAIL"
```

Expected: 21 tests pass.

- [ ] **Step 6: Commit**

```bash
git add workers/luma-api/src/store.ts workers/luma-api/src/email.ts workers/luma-api/src/index.ts workers/luma-api/test/store.test.ts
git commit -m "feat(backend): store products + email subscribe routes + full router"
```

---

### Task 9: Set secrets and deploy to Cloudflare

- [ ] **Step 1: Set Worker secrets via Wrangler**

```bash
cd workers/luma-api
npx wrangler secret put JWT_SECRET
# Prompt: enter a strong random string (32+ chars, keep in password manager)

npx wrangler secret put RESEND_API_KEY
# Prompt: enter your Resend API key from resend.com dashboard

npx wrangler secret put RESEND_AUDIENCE_ID
# Prompt: enter the Resend audience ID for the marketing list
```

- [ ] **Step 2: Apply migration to production D1**

```bash
npx wrangler d1 migrations apply luma --remote
```

Expected: `✅ Migration 0001_initial applied`

- [ ] **Step 3: Deploy**

```bash
npx wrangler deploy
```

Expected output contains: `Deployed luma-api ... https://luma-api.<your-subdomain>.workers.dev`

- [ ] **Step 4: Smoke-test the live API**

```bash
curl -X POST https://luma-api.<subdomain>.workers.dev/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@test.com","password":"smoketest123"}' \
  && echo ""
```

Expected: `{"message":"Verification email sent. Check your inbox."}`

```bash
curl https://luma-api.<subdomain>.workers.dev/store/products
```

Expected: `{"products":[]}` (no products seeded yet — seed via D1 console or a seed script)

- [ ] **Step 5: Note the Worker URL and update iOS plan**

Open `docs/superpowers/plans/2026-06-14-monetization-ios.md` and replace `WORKER_URL` placeholder with the deployed URL.

- [ ] **Step 6: Commit**

```bash
git add workers/luma-api/wrangler.toml
git commit -m "feat(backend): deploy Cloudflare Worker — luma-api live"
```
