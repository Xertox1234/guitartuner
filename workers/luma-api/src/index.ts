import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)

export default app
