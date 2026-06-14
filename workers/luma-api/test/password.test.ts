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
