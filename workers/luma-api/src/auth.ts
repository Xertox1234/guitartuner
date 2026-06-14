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
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return jsonError('Valid email address required', 400)
  }
  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(email).first()
  if (existing) return jsonError('An account with this email exists — sign in instead', 409)

  const id = randomUUID()
  const hash = await hashPassword(password)
  try {
    await c.env.DB.prepare(
      'INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)'
    ).bind(id, email, hash).run()
  } catch (e: unknown) {
    if (e instanceof Error && e.message.includes('UNIQUE constraint failed')) {
      return jsonError('An account with this email exists — sign in instead', 409)
    }
    throw e
  }

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
