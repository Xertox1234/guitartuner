import { defineWorkersConfig } from '@cloudflare/vitest-pool-workers/config'

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: './wrangler.toml' },
        miniflare: {
          bindings: {
            JWT_SECRET: 'test-secret-32-chars-minimum-ok',
            RESEND_API_KEY: 're_test_key',
            RESEND_AUDIENCE_ID: 'test-audience-id',
            APPLE_BUNDLE_ID: 'com.luma.tuner',
          },
        },
      },
    },
  },
})
