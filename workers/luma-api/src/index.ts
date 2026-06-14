import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'
import { tuningRoutes } from './tunings'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)
app.route('/tunings', tuningRoutes)

export default app
