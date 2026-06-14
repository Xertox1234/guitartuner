import { describe, it, expect, beforeEach, vi } from 'vitest'
import { env } from 'cloudflare:test'
import worker from '../src/index'
import { hashPassword } from '../src/password'
import { seedUser } from './helpers'

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
