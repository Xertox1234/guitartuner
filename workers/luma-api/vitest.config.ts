import { cloudflareTest } from '@cloudflare/vitest-pool-workers'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: './wrangler.toml' },
      miniflare: {
        bindings: {
          JWT_SECRET: 'test-secret-32-chars-minimum-ok',
          RESEND_API_KEY: 're_test_key',
          RESEND_AUDIENCE_ID: 'test-audience-id',
          APPLE_BUNDLE_ID: 'com.luma.tuner',
        },
      },
    }),
  ],
})
