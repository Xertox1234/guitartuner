export interface JWTPayload {
  sub: string
  iat: number
  exp: number
}

function b64url(buf: ArrayBuffer | Uint8Array): string {
  const bytes = buf instanceof ArrayBuffer ? new Uint8Array(buf) : buf
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function decodeB64url(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(s.length + (4 - (s.length % 4)) % 4, '=')
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

async function hmacKey(secret: string, usage: KeyUsage): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, [usage]
  )
}

export function makePayload(userId: string): JWTPayload {
  const now = Math.floor(Date.now() / 1000)
  return { sub: userId, iat: now, exp: now + 30 * 24 * 60 * 60 }
}

export async function sign(payload: JWTPayload, secret: string): Promise<string> {
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' })))
  const body = b64url(new TextEncoder().encode(JSON.stringify(payload)))
  const data = `${header}.${body}`
  const key = await hmacKey(secret, 'sign')
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data))
  return `${data}.${b64url(sig)}`
}

export async function verify(token: string, secret: string): Promise<JWTPayload> {
  const payload = await verifySignature(token, secret)
  if (payload.exp < Math.floor(Date.now() / 1000)) throw new Error('JWT expired')
  return payload
}

export async function verifyExpired(token: string, secret: string): Promise<JWTPayload> {
  const payload = await verifySignature(token, secret)
  const graceCutoff = Math.floor(Date.now() / 1000) - 7 * 24 * 60 * 60
  if (payload.exp < graceCutoff) throw new Error('JWT too old to refresh')
  return payload
}

async function verifySignature(token: string, secret: string): Promise<JWTPayload> {
  const parts = token.split('.')
  if (parts.length !== 3) throw new Error('Invalid JWT format')
  const [header, body, sig] = parts
  const key = await hmacKey(secret, 'verify')
  const valid = await crypto.subtle.verify(
    'HMAC', key, decodeB64url(sig),
    new TextEncoder().encode(`${header}.${body}`)
  )
  if (!valid) throw new Error('Invalid JWT signature')
  return JSON.parse(new TextDecoder().decode(decodeB64url(body))) as JWTPayload
}
