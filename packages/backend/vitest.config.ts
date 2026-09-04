import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const src = (p: string) => fileURLToPath(new URL(p, import.meta.url));

export default defineConfig({
  resolve: {
    alias: [
      { find: "@honey/shared/api", replacement: src("../shared/src/api/contract.ts") },
      { find: "@honey/shared/community-v2", replacement: src("../shared/src/community-v2/index.ts") },
      { find: "@honey/shared/access", replacement: src("../shared/src/access/index.ts") },
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
