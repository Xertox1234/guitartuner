const RESEND = 'https://api.resend.com'

export async function sendVerificationEmail(
  to: string,
  verifyToken: string,
  apiKey: string
): Promise<void> {
  const deepLink = `lumatuner://verify?token=${encodeURIComponent(verifyToken)}`
  await fetch(`${RESEND}/emails`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: 'LUMA <noreply@mail.lumatuner.com>',
      to,
      subject: 'Verify your LUMA account',
      html: `<p>Tap to verify: <a href="${deepLink}">Verify Email</a></p><p>Token: <code>${verifyToken}</code></p>`,
    }),
  })
}

export async function subscribeToMarketing(
  email: string,
  audienceId: string,
  apiKey: string
): Promise<void> {
  await fetch(`${RESEND}/audiences/${audienceId}/contacts`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, unsubscribed: false }),
  })
}

export async function unsubscribeFromMarketing(
  email: string,
  audienceId: string,
  apiKey: string
): Promise<void> {
  await fetch(`${RESEND}/audiences/${audienceId}/contacts`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, unsubscribed: true }),
  })
}
