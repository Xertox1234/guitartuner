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
