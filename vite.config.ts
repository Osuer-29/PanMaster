import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

<<<<<<< HEAD
export default defineConfig(({ mode }) => ({
  base: mode === 'desktop' ? './' : '/PanMaster/',
  plugins: [react()],
=======
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
>>>>>>> 74e96a59893b11d6eb11650382b6999f9f07f4b5
  server: {
    host: '0.0.0.0',
  },
  preview: {
    host: '0.0.0.0',
  },
<<<<<<< HEAD
}));
=======
}));
>>>>>>> 74e96a59893b11d6eb11650382b6999f9f07f4b5
