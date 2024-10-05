import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    target: 'es6', // Ändere dies bei Bedarf auf 'es5'
    rollupOptions: {
      output: {
        format: 'es'
      }
    }
  }
})
