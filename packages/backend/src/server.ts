import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { buildApp } from "./app.js";

// Bind to $PORT on the host hostd expects (loopback in production). Default web
// dist resolves relative to the working directory (the repo root at runtime),
// so a single Node service serves both API and web with no extra config.
const port = Number(process.env.PORT ?? 8080);
const host = process.env.HOST ?? "127.0.0.1";

const defaultWebDist = resolve(process.cwd(), "apps/web/dist");
const webDist = process.env.HONEY_WEB_DIST ?? (existsSync(defaultWebDist) ? defaultWebDist : undefined);

const app = buildApp(webDist ? { webDist } : {});

// Report re-evaluation retry queue (review v3 §12.15B): re-run verdicts that
// failed closed (classifier unavailable/uncertain). unref() — never keeps the
// process alive on its own.
setInterval(() => {
  void app.ctx.experiences.processPendingReevaluations().catch(() => undefined);
}, 10 * 60_000).unref();

app
  .listen({ port, host })
  .then((addr) => {
    // eslint-disable-next-line no-console
    console.log(`honey-backend listening on ${addr}${webDist ? ` (serving web from ${webDist})` : ""}`);
  })
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error(err);
    process.exit(1);
  });
