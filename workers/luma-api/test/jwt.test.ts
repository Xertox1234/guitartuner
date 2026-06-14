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
