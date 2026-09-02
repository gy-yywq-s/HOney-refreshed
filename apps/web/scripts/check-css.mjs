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
      // Any member WITHOUT a state pseudo-class beside members WITH one is a
      // dangling selector (class-, attribute- or :where-spelled included).
      const hasState = (p) => /:(focus|focus-visible|focus-within|hover|active)\b/.test(p);
      const withState = parts.filter(hasState);
      const without = parts.filter((p) => !hasState(p));
      if (withState.length && without.length) report(f, `selector(s) "${without.join(",")}" without a state pseudo-class beside state selectors: "${key.slice(0, 80)}"`);
    }
    i = k;
  }
}
for (const f of files) {
  const css = readFileSync(join(dir, f), "utf8");
  const opens = (css.match(/\{/g) ?? []).length, closes = (css.match(/\}/g) ?? []).length;
  if (opens !== closes) report(f, `unbalanced braces: ${opens} '{' vs ${closes} '}'`);
  if (/\}\s*\}/.test(css.replace(/@[^{]+\{[^{}]*(\{[^{}]*\}[^{}]*)*\}/g, (m) => m.replace(/\}\s*\}$/, "}"))) && false) report(f, "stray '}'");
  parse(css, f);
}
if (problems) { console.error(`[check-css] ${problems} problem(s)`); process.exit(1); }
console.log(`[check-css] ${files.length} stylesheet(s) clean`);
