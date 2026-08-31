import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const src = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  resolve: {
    alias: [
      { find: "@honey/shared", replacement: src("../shared/src/index.ts") },
      { find: "@honey/portal-connector/testing", replacement: src("../portal-connector/src/testing/mockPortal.ts") },
      { find: "@honey/portal-connector", replacement: src("../portal-connector/src/index.ts") },
    ],
  },
  test: {
    testTimeout: 15_000,
    server: { deps: { external: [/^node:sqlite$/] } },
  },
});
