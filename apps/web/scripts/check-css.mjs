// Served-CSS parse gate (design-is r8): fails the build when the emitted
// stylesheet carries a declaration outside a selector block, a selector
// list that mixes a bare element/class token with pseudo-class selectors
// (a dangling `button,` once put a focus ring on every button at rest),
// or the same selector twice in one context.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const dir = process.argv[2] ?? "dist/assets";
const files = readdirSync(dir).filter((f) => f.endsWith(".css"));
let problems = 0;
function report(f, msg) { problems++; console.error(`[check-css] ${f}: ${msg}`); }

function parse(css, f, ctx = "root", seen = new Map()) {
  let i = 0;
  while (i < css.length) {
    const open = css.indexOf("{", i);
    const semi = css.indexOf(";", i);
    if (open === -1) {
      if (css.slice(i).trim()) report(f, `declaration outside a block in ${ctx}: "${css.slice(i).trim().slice(0, 60)}"`);
      break;
    }
    if (semi !== -1 && semi < open && ctx !== "rule") {
      const stray = css.slice(i, semi).trim();
      if (stray && !stray.startsWith("@")) report(f, `declaration outside a block in ${ctx}: "${stray.slice(0, 60)}"`);
      i = semi + 1; continue;
    }
    const head = css.slice(i, open).trim();
    let depth = 1, k = open + 1;
    while (k < css.length && depth) { if (css[k] === "{") depth++; else if (css[k] === "}") depth--; k++; }
    const body = css.slice(open + 1, k - 1);
    if (head.startsWith("@media") || head.startsWith("@supports") || head.startsWith("@layer")) {
      parse(body, f, head, new Map());
    } else if (head.startsWith("@")) {
      // keyframes/font-face: bodies are fine
    } else {
      const key = head.replace(/\s+/g, " ");
      if (seen.has(key)) report(f, `duplicate selector in ${ctx}: "${key.slice(0, 80)}"`);
      seen.set(key, true);
      if (body.includes("{")) report(f, `nested block inside a rule: "${key.slice(0, 60)}"`);
      const parts = key.split(",").map((s) => s.trim());
      const pseudo = parts.filter((p) => /:focus|:hover|:active/.test(p));
      const bare = parts.filter((p) => /^[a-z]+$/.test(p));
      if (pseudo.length && bare.length) report(f, `bare selector "${bare.join(",")}" mixed with state selectors: "${key.slice(0, 80)}"`);
    }
    i = k;
  }
}
for (const f of files) parse(readFileSync(join(dir, f), "utf8"), f);
if (problems) { console.error(`[check-css] ${problems} problem(s)`); process.exit(1); }
console.log(`[check-css] ${files.length} stylesheet(s) clean`);
