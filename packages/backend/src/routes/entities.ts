import type { FastifyInstance } from "fastify";
import type { EntitiesResponse } from "@honey/shared/api";
import type { AppContext } from "../context.js";

// The public entity directory (canonical teachers · courses · rooms · dishes).
// Posts live in the Community process; this is the name source clients join
// Community's id-only payloads against.

export function registerEntityRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get<{ Querystring: { type?: string; q?: string } }>("/api/entities", { preHandler: ctx.requireAuth }, async (req): Promise<EntitiesResponse> => {
    const type = req.query.type as "teacher" | "course" | "room" | "dish" | undefined;
    return { entities: ctx.entities.list(type, req.query.q).map(({ entity_key, type: t, name, source }) => ({ entity_key, type: t, name, source })) };
  });
}
