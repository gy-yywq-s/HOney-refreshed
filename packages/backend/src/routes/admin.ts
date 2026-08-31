import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { AppContext } from "../context.js";
import type { KillSwitch, StandaloneMode } from "../experiences/settings.js";
import { markHash } from "../experiences/pass.js";
import { POLICY_VERSION } from "../experiences/policy.js";

// Admin dash API (Gary: studentId 0088 ⇒ admin). Ops only: kill switches,
// standalone-eligibility modes, entity import, invites, LLM config, reports.
// There is deliberately NO author-lookup capability anywhere here (App A §22.2).

const KILL_SWITCHES: KillSwitch[] = [
  "DISABLE_NEW_PUBLICATIONS",
  "DISABLE_REACTIONS",
  "HIDE_PUBLIC_EXPERIENCES",
  "PRIVATE_NOTES_ONLY_MODE",
];

export function registerAdminRoutes(app: FastifyInstance, ctx: AppContext): void {
  const requireAdmin = async (req: FastifyRequest, reply: FastifyReply) => {
    await ctx.requireAuth(req, reply);
    if (reply.sent) return;
    if (!ctx.accounts.isAdmin(ctx.userOf(req).honey_id)) {
      await reply.code(403).send({ error: "admin_only" });
    }
  };

  app.get("/api/admin/overview", { preHandler: requireAdmin }, async () => {
    const counts = ctx.db
      .prepare(
        `SELECT
           (SELECT COUNT(*) FROM honey_users) AS users,
           (SELECT COUNT(*) FROM experiences WHERE status = 'published') AS published,
           (SELECT COUNT(*) FROM experiences WHERE status = 'pending') AS pending,
           (SELECT COUNT(*) FROM reports WHERE outcome = 'pending') AS openReports,
           (SELECT COUNT(*) FROM entity_registry WHERE active = 1) AS entities`,
      )
      .get() as Record<string, number>;
    return {
      counts,
      policyVersion: POLICY_VERSION,
      killSwitches: Object.fromEntries(KILL_SWITCHES.map((k) => [k, ctx.settings.killSwitch(k)])),
      llm: {
        configured: ctx.settings.llmConfig() !== null,
        model: ctx.settings.get("llm.model") ?? "mistralai/mistral-small-3.2-24b-instruct",
      },
    };
  });

  app.post<{ Body: { name?: string; on?: boolean } }>(
    "/api/admin/kill-switch",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { name, on } = req.body ?? {};
      if (!KILL_SWITCHES.includes(name as KillSwitch) || typeof on !== "boolean") {
        return reply.code(400).send({ error: "name (valid switch) and on (boolean) required" });
      }
      ctx.settings.setKillSwitch(name as KillSwitch, on);
      return { ok: true };
    },
  );

  app.post<{ Body: { entityKey?: string; frozen?: boolean } }>(
    "/api/admin/freeze-entity",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { entityKey, frozen } = req.body ?? {};
      if (!entityKey || typeof frozen !== "boolean") {
        return reply.code(400).send({ error: "entityKey and frozen required" });
      }
      ctx.settings.setFrozenEntity(entityKey, frozen);
      return { ok: true };
    },
  );

  /** Standalone-review eligibility: per type (`type.<type>`) or per entity key. */
  app.post<{ Body: { scope?: string; mode?: string } }>(
    "/api/admin/standalone-mode",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { scope, mode } = req.body ?? {};
      const valid: StandaloneMode[] = ["verified", "open", "invite", "closed"];
      if (!scope || !valid.includes(mode as StandaloneMode)) {
        return reply.code(400).send({ error: "scope and mode(verified|open|invite|closed) required" });
      }
      ctx.settings.setStandaloneMode(scope, mode as StandaloneMode);
      return { ok: true };
    },
  );

  /** Bulk entity import (union with organic; deduped by type+name). */
  app.post<{ Body: { items?: { type?: string; name?: string }[] } }>(
    "/api/admin/entities/import",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const items = req.body?.items;
      if (!Array.isArray(items)) return reply.code(400).send({ error: "items[] required" });
      const cleaned = items
        .filter((i) => ["teacher", "room", "dish"].includes(i?.type ?? "") && typeof i?.name === "string")
        .map((i) => ({ type: i.type as "teacher" | "room" | "dish", name: i.name as string }));
      const result = ctx.entities.adminImport(cleaned);
      return { ok: true, ...result, skippedInvalid: items.length - cleaned.length };
    },
  );

  app.post<{ Body: { entityKey?: string; active?: boolean } }>(
    "/api/admin/entities/active",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { entityKey, active } = req.body ?? {};
      if (!entityKey || typeof active !== "boolean") {
        return reply.code(400).send({ error: "entityKey and active required" });
      }
      ctx.entities.setActive(entityKey, active);
      return { ok: true };
    },
  );

  /** Invite a specific student (by school studentId) to review a standalone entity. */
  app.post<{ Body: { entityKey?: string; studentId?: string } }>(
    "/api/admin/invite",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { entityKey, studentId } = req.body ?? {};
      if (!entityKey || !studentId) return reply.code(400).send({ error: "entityKey and studentId required" });
      const row = ctx.db
        .prepare("SELECT honey_id FROM school_connections WHERE student_id = ?")
        .get(studentId) as unknown as { honey_id: string } | undefined;
      if (!row) return reply.code(404).send({ error: "student_not_found" });
      ctx.db
        .prepare("INSERT INTO invite_marks (entity_key, mark_hash) VALUES (?, ?) ON CONFLICT DO NOTHING")
        .run(entityKey, markHash(ctx.config.sealKey, row.honey_id, `invite:${entityKey}`));
      return { ok: true };
    },
  );

  app.post<{ Body: { apiKey?: string; model?: string } }>(
    "/api/admin/llm",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const { apiKey, model } = req.body ?? {};
      if (apiKey) ctx.settings.setLlmKey(apiKey);
      if (model) ctx.settings.setLlmModel(model);
      if (!apiKey && !model) return reply.code(400).send({ error: "apiKey or model required" });
      return { ok: true, configured: ctx.settings.llmConfig() !== null };
    },
  );

  /** Live LLM health probe (uses a fixed innocuous sample). */
  app.post("/api/admin/llm/test", { preHandler: requireAdmin }, async () => {
    const verdict = await ctx.experiences.llmRunner("The library chairs are comfortable.");
    return { ok: verdict.ok, latencyMs: verdict.latencyMs ?? null, model: verdict.model ?? null };
  });

  app.get("/api/admin/reports", { preHandler: requireAdmin }, async () => {
    return {
      reports: ctx.db
        .prepare("SELECT * FROM reports ORDER BY created_at DESC LIMIT 200")
        .all(),
    };
  });

  app.post<{ Body: { minCount?: number } }>(
    "/api/admin/reaction-min-count",
    { preHandler: requireAdmin },
    async (req, reply) => {
      const n = req.body?.minCount;
      if (typeof n !== "number" || n < 0) return reply.code(400).send({ error: "minCount >= 0 required" });
      ctx.settings.set("reactions.minCount", String(n));
      return { ok: true };
    },
  );
}
