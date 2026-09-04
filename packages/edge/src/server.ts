import { createEdge } from "./proxy.js";

// Public port (the Cloudflare tunnel's target). The three services are
// loopback-only and never receive the public port directly.
const port = Number(process.env.EDGE_PORT ?? 8871);
const host = process.env.HOST ?? "127.0.0.1";

const server = createEdge({
  core: { host: "127.0.0.1", port: Number(process.env.CORE_PORT ?? 8872) },
  community: { host: "127.0.0.1", port: Number(process.env.COMMUNITY_PORT ?? 8873) },
  access: { host: "127.0.0.1", port: Number(process.env.ACCESS_PORT ?? 8874) },
  maxBodyBytes: 256 * 1024,
  headersTimeoutMs: 60_000,
  log: (line) => {
    // Lane + status + duration only: no path, no query, no header, no body.
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(line));
  },
});
server.keepAliveTimeout = 65_000;
server.listen(port, host, () => {
  // eslint-disable-next-line no-console
  console.log(`honey-edge listening on http://${host}:${port}`);
});
