import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { buildApp } from "./app.js";

// Loopback only, behind the edge proxy (packages/edge) which owns the public
// port. Default web dist resolves relative to the working directory (the repo
// root at runtime), so Core serves both the API and the built web app.
const port = Number(process.env.PORT ?? 8872);
const host = process.env.HOST ?? "127.0.0.1";

const defaultWebDist = resolve(process.cwd(), "apps/web/dist");
const webDist = process.env.HONEY_WEB_DIST ?? (existsSync(defaultWebDist) ? defaultWebDist : undefined);

const app = buildApp(webDist ? { webDist } : {});

// Issuance marks older than two days carry nothing worth keeping.
setInterval(() => app.ctx.limits.sweep(), 6 * 3600_000).unref();

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
