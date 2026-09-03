import { buildAccessApp } from "./app.js";
import { loadAccessConfig } from "./config.js";

const config = loadAccessConfig();
const port = Number(process.env.PORT ?? 8874);
const host = process.env.HOST ?? "127.0.0.1"; // loopback only; the edge is the public face

const built = await buildAccessApp({ config });
await built.app.listen({ port, host });
console.log(`[honey-access] ${config.serviceVersion} listening on http://${host}:${port} (portal egress: ${config.allowedEgressOrigins.join(", ")})`);

const shutdown = async () => {
  await built.close();
  process.exit(0);
};
process.on("SIGTERM", () => void shutdown());
process.on("SIGINT", () => void shutdown());
