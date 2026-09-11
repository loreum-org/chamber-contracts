import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
  resolve: {
    alias: [
      {
        find: /^@\/contracts\/(.+)$/,
        replacement: `${path.resolve(__dirname, './contracts')}/$1`,
      },
      {
        find: /^@\/contracts$/,
        replacement: path.resolve(__dirname, './contracts'),
      },
      {
        find: '@',
        replacement: path.resolve(__dirname, './src'),
      },
    ],
  },
  define: {
    global: 'globalThis',
  },
})
