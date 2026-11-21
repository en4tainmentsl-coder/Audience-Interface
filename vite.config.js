import path from 'path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(() => {
    return {
      server: {
        port: 3000,
        host: '0.0.0.0',
      },
      plugins: [react()],
      resolve: {
        alias: {
          '@': path.resolve(__dirname, '.'),
        }
      },
      build: {
        rollupOptions: {
          output: {
            // Only these two groups are named, on purpose.
            //
            // DO NOT add a catch-all `return 'vendor'` for node_modules.
            // framer-motion (~126 kB) is imported by exactly one route,
            // VenuePortal, which is lazy. A catch-all pulls it back into
            // the eager graph and makes first paint ~137 kB worse,
            // undoing the route splitting in PR #208. Measured, not guessed.
            //
            // Renaming these groups changes their filenames and busts the
            // cache for every returning visitor. Keep the names stable.
            manualChunks(id) {
              if (!id.includes('node_modules')) return;
              if (/node_modules[\\/](react|react-dom|scheduler|react-router)[\\/]/.test(id)) return 'react-vendor';
              if (/node_modules[\\/]@supabase[\\/]/.test(id)) return 'supabase-vendor';
            },
          },
        },
      },
    };
});
