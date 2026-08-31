import { readdirSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

// Launch gate §26.2: verified ABSENCE of application logs that deliberately
// combine a post body/id with an account identity. This is a structural guard —
// it fails if any backend source starts logging in a way that could reconstruct
// author↔post linkage. It complements the runtime guarantees (no author column,
// abuse counters store no text) with a build-time check.

const backendSrc = fileURLToPath(new URL("../", import.meta.url));

function walk(dir: string): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) {
      if (name === "node_modules" || name === "dist") continue;
      out.push(...walk(p));
    } else if (name.endsWith(".ts") && !name.endsWith(".test.ts")) {
      out.push(p);
    }
  }
  return out;
}

describe("no author-linking logs (§26.2)", () => {
  const files = walk(backendSrc);

  it("scans the whole backend source tree", () => {
    expect(files.length).toBeGreaterThan(10);
  });

  it("no console.* / logger call references a post body together with an identity", () => {
    const offenders: string[] = [];
    const logCall = /(console\.\w+|\blog(?:ger)?\.\w+|req\.log\.\w+|fastify\.log\.\w+)\s*\(([^;]*)\)/g;
    for (const f of files) {
      const src = readFileSync(f, "utf8");
      let m: RegExpExecArray | null;
      while ((m = logCall.exec(src)) !== null) {
        const args = m[2] ?? "";
        const mentionsBody = /\bbody\b|\.body\b|ownershipKey|content_hash/.test(args);
        const mentionsIdentity = /honey_?[iI]d|studentId|username|password/.test(args);
        if (mentionsBody && mentionsIdentity) offenders.push(`${f}: ${m[0].slice(0, 80)}`);
      }
    }
    expect(offenders).toEqual([]);
  });

  it("Fastify runs with request logging disabled (no ambient body/route+ip logs)", () => {
    const appSrc = readFileSync(join(backendSrc, "app.ts"), "utf8");
    expect(appSrc).toMatch(/Fastify\(\{\s*logger:\s*false/);
  });
});
