// The checked-in JSON under packages/shared/fixtures/api MUST equal the
// typed literals in fixtures.ts — that is what makes the Swift decode tests
// a contract check rather than a decode-whatever-you-wrote test.
// Regenerate with `pnpm --filter @honey/shared fixtures:write`.

import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { FIXTURES } from "./fixtures.js";

const DIR = resolve(fileURLToPath(new URL(".", import.meta.url)), "../../fixtures/api");

describe("contract fixtures", () => {
  it("every literal has a JSON file that equals it", () => {
    for (const [name, value] of Object.entries(FIXTURES)) {
      const file = join(DIR, `${name}.json`);
      const parsed = JSON.parse(readFileSync(file, "utf8")) as unknown;
      expect(parsed, name).toEqual(value);
    }
  });

  it("no stray JSON file lacks a literal", () => {
    const names = readdirSync(DIR).filter((f) => f.endsWith(".json")).map((f) => f.slice(0, -5));
    for (const name of names) expect(name in FIXTURES, `${name}.json has no literal`).toBe(true);
  });
});
