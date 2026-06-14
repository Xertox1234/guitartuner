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
