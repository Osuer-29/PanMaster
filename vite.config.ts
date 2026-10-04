import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ command }) => ({
  base: './',
  plugins: [react()],
  define: command === 'build' ? {
    'process.env.NODE_ENV': JSON.stringify('production'),
  } : {},
  build: {
    outDir: 'publicacion',
    emptyOutDir: true,
    cssCodeSplit: false,
    minify: true,
    lib: {
      entry: 'src/main.tsx',
      name: 'PanMaster',
      formats: ['iife'],
      fileName: () => 'panmaster.js',
      cssFileName: 'panmaster',
    },
    rollupOptions: {
      output: { inlineDynamicImports: true },
    },
  },
  server: {
    host: '0.0.0.0',
  },
  preview: {
    host: '0.0.0.0',
  },
}));
