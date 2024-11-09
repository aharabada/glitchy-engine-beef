import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
    const isDebug = mode === 'debug'

    return {
        plugins: [react()],
        base: "./",
        build: {
            target: "es2015",
            minify: false,
            terserOptions: undefined,
            rollupOptions: {
                preserveModules: true,
                output: {
                    dir: 'dist',
                    entryFileNames: '[name].js',
                    chunkFileNames: '[name].js',
                    assetFileNames: '[name].[ext]'
                }
            }
        }
    }
})
