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
