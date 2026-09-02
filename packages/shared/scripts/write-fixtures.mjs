// Writes packages/shared/fixtures/api/<name>.json from the typed literals in
// src/api/fixtures.ts (run after `pnpm build`). Stable key order and 2-space
// indent so diffs stay readable.
import { mkdirSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const { FIXTURES } = await import(resolve(here, "../dist/api/fixtures.js"));
const dir = resolve(here, "../fixtures/api");
mkdirSync(dir, { recursive: true });
for (const f of readdirSync(dir)) if (f.endsWith(".json")) unlinkSync(join(dir, f));
for (const [name, value] of Object.entries(FIXTURES)) {
  writeFileSync(join(dir, `${name}.json`), JSON.stringify(value, null, 2) + "\n");
}
console.log(`wrote ${Object.keys(FIXTURES).length} fixtures to ${dir}`);
