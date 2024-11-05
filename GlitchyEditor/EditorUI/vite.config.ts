import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  base: "./",
  build:
  {
    target: "es2015",
    terserOptions: {
      mangle: {
        reserved: ['EngineGlue']
      }
    }
  }
})
