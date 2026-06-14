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

  const email = user.email
  if (!email) return jsonError('No email on record — Apple users cannot subscribe to marketing without a verified email address', 400)

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
