import { buildCommunityApp } from "./app.js";

// Loopback only: the edge proxy is the sole public path (and it strips
// identity material before anything reaches this process).
const port = Number(process.env.COMMUNITY_PORT ?? 8873);
const host = process.env.HOST ?? "127.0.0.1";

const app = buildCommunityApp({
  log: (line) => {
    // Route class, status, duration and a Community-local id only.
    // eslint-disable-next-line no-console
    console.log(JSON.stringify(line));
  },
});

setInterval(() => {
  void app.ctx.reactions.processPendingReevaluations().catch(() => undefined);
  app.ctx.redemption.sweep();
}, 10 * 60_000).unref();

app
  .listen({ port, host })
  .then((addr) => {
    // eslint-disable-next-line no-console
    console.log(`honey-community listening on ${addr}`);
  })
  .catch((err) => {
    // eslint-disable-next-line no-console
    console.error(err);
    process.exit(1);
  });
