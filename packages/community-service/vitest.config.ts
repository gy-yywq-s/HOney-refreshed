import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const src = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  resolve: {
    alias: [
      { find: "@honey/shared/api", replacement: src("../shared/src/api/contract.ts") },
      { find: "@honey/shared/community-v2", replacement: src("../shared/src/community-v2/index.ts") },
      { find: "@honey/shared", replacement: src("../shared/src/index.ts") },
    ],
  },
  test: {
    testTimeout: 30_000,
    server: { deps: { external: [/^node:sqlite$/] } },
  },
});
