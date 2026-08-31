import Fastify, { type FastifyInstance } from "fastify";

// Honey Core backend (Bands 3 & 4 live here). UI-agnostic domain API only.
export function buildApp(): FastifyInstance {
  const app = Fastify({ logger: false });

  app.get("/api/health", async () => ({ status: "ok", service: "honey-backend" }));

  return app;
}
