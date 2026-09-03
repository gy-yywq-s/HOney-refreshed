// Internal admin surface (spec §24.2 pattern, applied to Community): reached
// only through Core's Dash proxy on the loopback interface with a dedicated
// internal secret. It reports counts and settings and flips switches. It has
// no author lookup, no per-nym browsing, and its DTOs carry no tag or key.

import { timingSafeEqual } from "node:crypto";
import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { DatabaseSync } from "node:sqlite";
import { POLICY_VERSION } from "./moderation/index.js";
import { assertNoIdentityFields } from "./redaction.js";
import { KILL_SWITCHES, type CommunitySettings, type KillSwitch } from "./settings.js";
import type { ReactionService } from "./reactions.js";
import type { PublicationService } from "./publish.js";

export interface AdminDeps {
  db: DatabaseSync;
  settings: CommunitySettings;
  publication: PublicationService;
  reactions: ReactionService;
  internalSecret: string;
}

export function registerAdminRoutes(app: FastifyInstance, deps: AdminDeps): void {
  const requireInternal = async (req: FastifyRequest, reply: FastifyReply) => {
    const given = req.headers["x-honey-internal"];
    const ok =
      typeof given === "string" &&
      given.length === deps.internalSecret.length &&
      timingSafeEqual(Buffer.from(given), Buffer.from(deps.internalSecret)) &&
      (req.ip === "127.0.0.1" || req.ip === "::1" || req.ip === "::ffff:127.0.0.1");
    if (!ok) await reply.code(403).send({ error: "internal_only" });
  };

  app.get("/internal/admin/status", { preHandler: requireInternal }, async () => {
    const counts = deps.db
      .prepare(
        `SELECT
           (SELECT COUNT(*) FROM experiences WHERE status = 'published') AS published,
           (SELECT COUNT(*) FROM reports WHERE outcome IN ('pending', 'reevaluation_pending')) AS openReports,
           (SELECT COUNT(*) FROM community_suspensions WHERE suspended_until > ?) AS suspended`,
      )
      .get(Date.now()) as Record<string, number>;
    const body = {
      counts,
      policyVersion: POLICY_VERSION,
      killSwitches: Object.fromEntries(KILL_SWITCHES.map((k) => [k, deps.settings.killSwitch(k)])),
      cooldownHours: deps.settings.cooldownHours(),
      reactionMinCount: deps.settings.reactionMinCount(),
      llm: { configured: deps.settings.llmConfig() !== null, model: deps.settings.llmModel() },
    };
    assertNoIdentityFields(body);
    return body;
  });

  app.post<{ Body: { name?: string; on?: boolean } }>("/internal/admin/kill-switch", { preHandler: requireInternal }, async (req, reply) => {
    const { name, on } = req.body ?? {};
    if (!KILL_SWITCHES.includes(name as KillSwitch) || typeof on !== "boolean") return reply.code(400).send({ error: "bad_request" });
    deps.settings.setKillSwitch(name as KillSwitch, on);
    return { ok: true };
  });

  app.post<{ Body: { entityKey?: string; frozen?: boolean } }>("/internal/admin/freeze-entity", { preHandler: requireInternal }, async (req, reply) => {
    const { entityKey, frozen } = req.body ?? {};
    if (typeof entityKey !== "string" || !entityKey.includes(":") || typeof frozen !== "boolean") return reply.code(400).send({ error: "bad_request" });
    deps.settings.setFrozenEntity(entityKey, frozen);
    return { ok: true };
  });

  app.post<{ Body: { minCount?: number } }>("/internal/admin/reaction-min-count", { preHandler: requireInternal }, async (req, reply) => {
    const n = req.body?.minCount;
    if (typeof n !== "number" || n < 0 || !Number.isInteger(n)) return reply.code(400).send({ error: "bad_request" });
    deps.settings.set("reactions.minCount", String(n));
    return { ok: true };
  });

  app.post<{ Body: { hours?: number } }>("/internal/admin/cooldown-hours", { preHandler: requireInternal }, async (req, reply) => {
    const h = req.body?.hours;
    if (typeof h !== "number" || !Number.isInteger(h) || h < 1 || h > 168) return reply.code(400).send({ error: "bad_request" });
    deps.settings.set("cooldown.hours", String(h));
    return { ok: true };
  });

  app.post<{ Body: { apiKey?: string; model?: string } }>("/internal/admin/llm", { preHandler: requireInternal }, async (req, reply) => {
    const { apiKey, model } = req.body ?? {};
    if (typeof apiKey === "string" && apiKey) deps.settings.setLlmKey(apiKey);
    if (typeof model === "string" && model) deps.settings.set("llm.model", model);
    if (!apiKey && !model) return reply.code(400).send({ error: "bad_request" });
    return { ok: true, configured: deps.settings.llmConfig() !== null };
  });

  app.post("/internal/admin/llm/test", { preHandler: requireInternal }, async () => {
    const verdict = await deps.publication.llmRunner("The library chairs are comfortable.");
    return { ok: verdict.ok, latencyMs: verdict.latencyMs ?? null, model: verdict.model ?? null };
  });

  app.get("/internal/admin/reports", { preHandler: requireInternal }, async () => {
    const reports = deps.db
      .prepare("SELECT id, experience_id, category, outcome, created_at FROM reports ORDER BY created_at DESC LIMIT 200")
      .all();
    const body = { reports };
    assertNoIdentityFields(body);
    return body;
  });

  app.post("/internal/admin/reports/sweep", { preHandler: requireInternal }, async () => {
    return { processed: await deps.reactions.processPendingReevaluations() };
  });
}
