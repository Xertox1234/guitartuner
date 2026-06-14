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
