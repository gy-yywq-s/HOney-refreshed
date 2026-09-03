import { execSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import type { Plugin } from "vite";
import react from "@vitejs/plugin-react";

// One build id, in the bundle AND at /version.json (no-cache at the origin,
// not in the edge's default cache list): the running app compares the two
// on resume and reloads itself, so no device keeps an older build alive
// beside a newer one (Gary 2026-09-02: "versions jumping back and forth").
function buildId(): string {
  try {
    return execSync("git rev-parse --short HEAD", { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch {
    return String(Date.now());
  }
}
const BUILD = buildId();
function versionFile(): Plugin {
  return {
    name: "honey-version-file",
    writeBundle(options) {
      const dir = options.dir ?? "dist";
      mkdirSync(dir, { recursive: true });
      writeFileSync(`${dir}/version.json`, JSON.stringify({ build: BUILD, at: new Date().toISOString() }));
    },
  };
}

export default defineConfig({
  plugins: [react(), versionFile()],
  define: { __BUILD__: JSON.stringify(BUILD) },
  resolve: {
    alias: {
      "@honey/shared/api": fileURLToPath(new URL("../../packages/shared/src/api/contract.ts", import.meta.url)),
      "@honey/shared/community-v2": fileURLToPath(new URL("../../packages/shared/src/community-v2/index.ts", import.meta.url)),
      "@honey/shared/access": fileURLToPath(new URL("../../packages/shared/src/access/index.ts", import.meta.url)),
      "@honey/shared": fileURLToPath(new URL("../../packages/shared/src/index.ts", import.meta.url)),
    },
  },
  server: {
    port: 5173,
    // Backend is same-origin in prod; in dev, proxy /api to the local backend.
    proxy: { "/api": "http://127.0.0.1:8080" },
  },
  build: { outDir: "dist" },
});
