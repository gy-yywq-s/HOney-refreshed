import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@honey/shared/api": fileURLToPath(new URL("../../packages/shared/src/api/contract.ts", import.meta.url)),
      "@honey/shared": fileURLToPath(new URL("../../packages/shared/src/index.ts", import.meta.url)),
    },
  },
  server: {
    port: 5174,
    // Backend is same-origin in prod; in dev, proxy /api to the local backend.
    proxy: { "/api": "http://127.0.0.1:8080" },
  },
  build: { outDir: "dist" },
});
