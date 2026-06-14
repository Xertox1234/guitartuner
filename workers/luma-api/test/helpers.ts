export async function seedUser(
  db: D1Database,
  overrides: Partial<{ id: string; email: string; password_hash: string; apple_sub: string; verified: number }>
) {
  const row = {
    id: overrides.id ?? 'user-seed-1',
    email: overrides.email ?? 'seed@example.com',
    password_hash: overrides.password_hash ?? null,
    apple_sub: overrides.apple_sub ?? null,
    verified: overrides.verified ?? 1,
  }
  await db.prepare(
    'INSERT OR REPLACE INTO users (id, email, password_hash, apple_sub, verified) VALUES (?, ?, ?, ?, ?)'
  ).bind(row.id, row.email, row.password_hash, row.apple_sub, row.verified).run()
  return row
}
