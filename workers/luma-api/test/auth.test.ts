import { describe, it, expect, beforeEach, vi } from 'vitest'
import { env } from 'cloudflare:test'
import worker from '../src/index'
import { hashPassword } from '../src/password'
import { sign, makePayload } from '../src/jwt'
import { seedUser } from './helpers'

const SECRET = 'test-secret-32-chars-minimum-ok'
async function authHeader(userId: string) {
  return `Bearer ${await sign(makePayload(userId), SECRET)}`
}

// Mock sendVerificationEmail so tests don't make real Resend HTTP calls
vi.mock('../src/resend', () => ({
  sendVerificationEmail: vi.fn().mockResolvedValue(undefined),
  subscribeToMarketing: vi.fn().mockResolvedValue(undefined),
  unsubscribeFromMarketing: vi.fn().mockResolvedValue(undefined),
}))

describe('POST /auth/register', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM users')
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

describe('DELETE /auth/account', () => {
  beforeEach(async () => {
    await env.DB.exec('DELETE FROM tuning_cards; DELETE FROM users')
  })

  it('deletes the authenticated user and returns { deleted: true }', async () => {
    await seedUser(env.DB, { id: 'del-user-1' })
    const res = await worker.fetch(
      new Request('http://localhost/auth/account', {
        method: 'DELETE',
        headers: { Authorization: await authHeader('del-user-1') },
      }),
      env
    )
    expect(res.status).toBe(200)
    const body = await res.json<{ deleted: boolean }>()
    expect(body.deleted).toBe(true)
    const row = await env.DB.prepare('SELECT id FROM users WHERE id = ?')
      .bind('del-user-1').first()
    expect(row).toBeNull()
  })

  it('cascades deletion to tuning_cards', async () => {
    await seedUser(env.DB, { id: 'del-user-2' })
    await env.DB.prepare(
      'INSERT INTO tuning_cards (id, user_id, name, notes, instrument, a4, palette, strings_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).bind('card-del-1', 'del-user-2', 'Open G', '', 'guitar', 440, 'aurora', '[]').run()
    await worker.fetch(
      new Request('http://localhost/auth/account', {
        method: 'DELETE',
        headers: { Authorization: await authHeader('del-user-2') },
      }),
      env
    )
    const card = await env.DB.prepare('SELECT id FROM tuning_cards WHERE user_id = ?')
      .bind('del-user-2').first()
    expect(card).toBeNull()
  })

  it('returns 401 without auth header', async () => {
    const res = await worker.fetch(
      new Request('http://localhost/auth/account', { method: 'DELETE' }),
      env
    )
    expect(res.status).toBe(401)
  })

  it('returns 404 when user row is already gone (stale JWT)', async () => {
    await seedUser(env.DB, { id: 'del-user-3' })
    const header = await authHeader('del-user-3')
    await env.DB.prepare('DELETE FROM users WHERE id = ?').bind('del-user-3').run()
    const res = await worker.fetch(
      new Request('http://localhost/auth/account', {
        method: 'DELETE',
        headers: { Authorization: header },
      }),
      env
    )
    expect(res.status).toBe(404)
  })
})
