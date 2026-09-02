import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  base: '/hexrack-sbc/', // GitHub Pages base path
  // The engraver worker loads OpenSCAD's wasm glue, which is an ES module fetched at build
  // time into public/wasm rather than bundled. A classic worker cannot import it.
  worker: { format: 'es' },
})
