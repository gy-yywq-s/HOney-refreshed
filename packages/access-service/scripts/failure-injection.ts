// Runs the failure-injection matrix and writes the transcript that the
// acceptance criteria ask for (spec §26.2):
//   pnpm --filter @honey/access-service exec tsx scripts/failure-injection.ts [out.md]
import { writeFileSync } from "node:fs";
import { renderTranscript, runInjections } from "../src/testing/injection.js";

const out = process.argv[2] ?? `docs/status/web-access-failure-injection-${new Date().toISOString().slice(0, 10)}.md`;
const results = await runInjections();
const md = renderTranscript(results, { date: new Date().toISOString().slice(0, 10), version: process.env.HONEY_SERVICE_VERSION ?? "local" });
writeFileSync(out, md);
console.log(md);
console.log(`written: ${out}`);
process.exit(results.every((r) => r.pass) ? 0 : 1);
