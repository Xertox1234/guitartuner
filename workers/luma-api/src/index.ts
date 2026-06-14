import { Hono } from 'hono'
import type { Env } from './types'
import { authRoutes } from './auth'
import { tuningRoutes } from './tunings'
import { storeRoutes } from './store'
import { emailRoutes } from './email'

const app = new Hono<{ Bindings: Env }>()
app.route('/auth', authRoutes)
app.route('/tunings', tuningRoutes)
app.route('/store', storeRoutes)
app.route('/email', emailRoutes)

export default app
