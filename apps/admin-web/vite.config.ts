/// <reference types="vitest/config" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
    css: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/main.tsx', 'src/**/*.d.ts', 'src/test/**'],
      // Floors, not goals: measured ~19% lines / ~77% branches at
      // introduction (only a first slice of services/hooks/components/
      // pages is covered so far) — these lock the floor so coverage can
      // only ratchet upward. Raise deliberately when new suites land.
      thresholds: {
        lines: 18,
        functions: 55,
        branches: 70,
        statements: 18,
      },
    },
  },
})
