import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Relative base so the build works from any static host or subfolder.
export default defineConfig({
  base: './',
  plugins: [react()],
  build: { assetsInlineLimit: 0 },
});
