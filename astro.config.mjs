import node from '@astrojs/node'
import tailwindcss from '@tailwindcss/vite'
import participantAuth from 'astro-participant-auth/integration'
import { defineConfig } from 'astro/config'

export default defineConfig({
  output: 'server',
  adapter: node({
    mode: 'standalone'
  }),
  integrations: [participantAuth({ displayName: '参加アプリ' })],
  session: false,
  server: {
    port: 4000,
    host: true
  },
  security: {
    checkOrigin: false
  },
  vite: {
    plugins: [tailwindcss()],
    server: {
      allowedHosts: true
    }
  }
})
