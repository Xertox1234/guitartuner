interface AppleJWK {
  kty: string; kid: string; use: string; alg: string; n: string; e: string
}

let jwksCache: { keys: AppleJWK[]; at: number } | null = null

async function getAppleKeys(): Promise<AppleJWK[]> {
  if (jwksCache && Date.now() - jwksCache.at < 3_600_000) return jwksCache.keys
  const r = await fetch('https://appleid.apple.com/auth/keys')
  const { keys } = await r.json<{ keys: AppleJWK[] }>()
  jwksCache = { keys, at: Date.now() }
  return keys
}

function decodeB64url(s: string): Uint8Array {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(s.length + (4 - (s.length % 4)) % 4, '=')
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0))
}

interface ApplePayload {
  iss: string; aud: string; sub: string; exp: number
}

/**
 * Validates an Apple identity token and returns the Apple user ID (`sub`).
 * Returns null if invalid. Throws on network errors.
 */
export async function validateAppleToken(
  token: string,
  bundleId: string
): Promise<string | null> {
  const parts = token.split('.')
  if (parts.length !== 3) return null

  let header: { kid: string; alg: string }
  let payload: ApplePayload
  try {
    header = JSON.parse(new TextDecoder().decode(decodeB64url(parts[0])))
    payload = JSON.parse(new TextDecoder().decode(decodeB64url(parts[1])))
  } catch {
    return null
  }

  if (payload.iss !== 'https://appleid.apple.com') return null
  if (payload.aud !== bundleId) return null
  if (payload.exp < Math.floor(Date.now() / 1000)) return null

  const keys = await getAppleKeys()
  const jwk = keys.find(k => k.kid === header.kid)
  if (!jwk) return null

  const key = await crypto.subtle.importKey(
    'jwk',
    { kty: 'RSA', n: jwk.n, e: jwk.e, alg: 'RS256', use: 'sig' } as JsonWebKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['verify']
  )

  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, decodeB64url(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
  )
  return valid ? payload.sub : null
}
