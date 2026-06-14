export interface Env {
  DB: D1Database
  JWT_SECRET: string
  RESEND_API_KEY: string
  RESEND_AUDIENCE_ID: string
  APPLE_BUNDLE_ID: string
}

export interface UserRow {
  id: string
  email: string | null
  apple_sub: string | null
  password_hash: string | null
  verified: number
  marketing_opt_in: number
  created_at: string
}

export interface TuningCardRow {
  id: string
  user_id: string
  name: string
  notes: string
  instrument: string
  a4: number
  palette: string
  strings_json: string
  created_at: string
}

export interface StoreProductRow {
  id: string
  category: string
  name: string
  description: string
  price_hint: string
  sweetwater_url: string
  image_url: string
  is_featured: number
  sort_order: number
}

export function jsonError(message: string, status: number): Response {
  return Response.json({ error: message }, { status })
}

export function jsonOk(data: unknown, headers?: HeadersInit): Response {
  return Response.json(data, { headers })
}
