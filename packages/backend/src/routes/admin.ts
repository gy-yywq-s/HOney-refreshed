import type { FastifyInstance, FastifyReply, FastifyRequest } from "fastify";
import type { AppContext } from "../context.js";
import type { KillSwitch, StandaloneMode } from "../experiences/settings.js";

// Admin dash API (Gary: studentId 0088 ⇒ admin). Core owns entities, invites,
// standalone modes and the issuance switches; everything about posts —
// moderation model, reports, thresholds, cooling-off — is proxied to the
// Community process's internal surface. There is deliberately NO author
// lookup anywhere: neither process can answer it (App A §22.2).

const CORE_SWITCHES: KillSwitch[] = ["DISABLE_NEW_PUBLICATIONS", "PRIVATE_NOTES_ONLY_MODE"];
const COMMUNITY_SWITCHES = ["DISABLE_NEW_PUBLICATIONS", "DISABLE_REACTIONS", "DISABLE_REPORTS", "HIDE_PUBLIC_EXPERIENCES"];

export function registerAdminRoutes(app: FastifyInstance, ctx: AppContext): void {
  const requireAdmin = async (req: FastifyRequest, reply: FastifyReply) => {
    await ctx.requireAuth(req, reply);
    if (reply.sent) return;
    if (!ctx.accounts.isAdmin(ctx.userOf(req).honey_id)) {
      await reply.code(403).send({ error: "admin_only" });
    }
  };

  app.get("/api/admin/overview", { preHandler: requireAdmin }, async () => {
    const users = (ctx.db.prepare("SELECT COUNT(*) AS n FROM honey_users").get() as { n: number }).n;
    let community: Awaited<ReturnType<typeof ctx.communityAdmin.status>> | null = null;
    try {
      community = await ctx.communityAdmin.status();
    } catch {
      community = null; // the Dash says so instead of failing whole
    }
    return {
      counts: {
        users,
        published: community?.counts.published ?? 0,
        openReports: community?.counts.openReports ?? 0,
        entities: ctx.entities.count(),
      },
      policyVersion: community?.policyVersion ?? 0,
      killSwitches: {
        ...Object.fromEntries(CORE_SWITCHES.map((k) => [k, ctx.settings.killSwitch(k)])),
        ...(community?.killSwitches ?? {}),
      },
      cooldownHours: community?.cooldownHours ?? 24,
      llm: community?.llm ?? { configured: false, model: "" },
      communityReachable: community !== null,
      issuerReady: ctx.issuer !== null,
    };
  });

  app.post<{ Body: { name?: string; on?: boolean } }>("/api/admin/kill-switch", { preHandler: requireAdmin }, async (req, reply) => {
    const { name, on } = req.body ?? {};
    if (typeof name !== "string" || typeof on !== "boolean") return reply.code(400).send({ error: "name and on (boolean) required" });
    const core = CORE_SWITCHES.includes(name as KillSwitch);
    const community = COMMUNITY_SWITCHES.includes(name);
    if (!core && !community) return reply.code(400).send({ error: "unknown switch" });
    if (core) ctx.settings.setKillSwitch(name as KillSwitch, on);
    if (community) await ctx.communityAdmin.setKillSwitch(name, on);
    return { ok: true };
  });

  app.post<{ Body: { entityKey?: string; frozen?: boolean } }>("/api/admin/freeze-entity", { preHandler: requireAdmin }, async (req, reply) => {
    const { entityKey, frozen } = req.body ?? {};
    if (!entityKey || typeof frozen !== "boolean") return reply.code(400).send({ error: "entityKey and frozen required" });
    ctx.settings.setFrozenEntity(entityKey, frozen);
    await ctx.communityAdmin.setFrozenEntity(entityKey, frozen);
    return { ok: true };
  });

  /** Standalone-review eligibility: per type (`type.<type>`) or per entity key. */
  app.post<{ Body: { scope?: string; mode?: string } }>("/api/admin/standalone-mode", { preHandler: requireAdmin }, async (req, reply) => {
    const { scope, mode } = req.body ?? {};
    const valid: StandaloneMode[] = ["verified", "open", "invite", "closed"];
    if (!scope || !valid.includes(mode as StandaloneMode)) return reply.code(400).send({ error: "scope and mode(verified|open|invite|closed) required" });
    ctx.settings.setStandaloneMode(scope, mode as StandaloneMode);
    return { ok: true };
  });

  /** Bulk entity import (union with canonical rows; deduped through aliases). */
  app.post<{ Body: { items?: { type?: string; name?: string }[] } }>("/api/admin/entities/import", { preHandler: requireAdmin }, async (req, reply) => {
    const items = req.body?.items;
    if (!Array.isArray(items)) return reply.code(400).send({ error: "items[] required" });
    const cleaned = items
      .filter((i) => ["teacher", "room", "dish"].includes(i?.type ?? "") && typeof i?.name === "string")
      .map((i) => ({ type: i.type as "teacher" | "room" | "dish", name: i.name as string }));
    const result = ctx.entities.adminImport(cleaned);
    return { ok: true, ...result, skippedInvalid: items.length - cleaned.length };
  });

  /** Source labels the canonical resolver could not place: visible here, never in a browse list. */
  app.get("/api/admin/import/unresolved", { preHandler: requireAdmin }, async () => ({ labels: ctx.importer.school.unresolvedLabels() }));

  app.post<{ Body: { entityKey?: string; active?: boolean } }>("/api/admin/entities/active", { preHandler: requireAdmin }, async (req, reply) => {
    const { entityKey, active } = req.body ?? {};
    if (!entityKey || typeof active !== "boolean") return reply.code(400).send({ error: "entityKey and active required" });
    ctx.entities.setActive(entityKey, active);
    return { ok: true };
  });

  /** Invite a specific student (by school studentId) to review a standalone entity. */
  app.post<{ Body: { entityKey?: string; studentId?: string } }>("/api/admin/invite", { preHandler: requireAdmin }, async (req, reply) => {
    const { entityKey, studentId } = req.body ?? {};
    if (!entityKey || !studentId) return reply.code(400).send({ error: "entityKey and studentId required" });
    const row = ctx.db.prepare("SELECT honey_id FROM school_connections WHERE student_id = ?").get(studentId) as { honey_id: string } | undefined;
    if (!row) return reply.code(404).send({ error: "student_not_found" });
    ctx.db.prepare("INSERT INTO invite_marks (entity_key, mark_hash) VALUES (?, ?) ON CONFLICT DO NOTHING").run(entityKey, ctx.eligibility.inviteMark(row.honey_id, entityKey));
    return { ok: true };
  });

  // ---- proxied to the Community process ----
  app.post<{ Body: { apiKey?: string; model?: string } }>("/api/admin/llm", { preHandler: requireAdmin }, async (req, reply) => {
    const { apiKey, model } = req.body ?? {};
    if (!apiKey && !model) return reply.code(400).send({ error: "apiKey or model required" });
    const input: { apiKey?: string; model?: string } = {};
    if (apiKey) input.apiKey = apiKey;
    if (model) input.model = model;
    return ctx.communityAdmin.setLlm(input);
  });
  app.post("/api/admin/llm/test", { preHandler: requireAdmin }, async () => ctx.communityAdmin.testLlm());
  app.get("/api/admin/reports", { preHandler: requireAdmin }, async () => ctx.communityAdmin.reports());
  app.post<{ Body: { minCount?: number } }>("/api/admin/reaction-min-count", { preHandler: requireAdmin }, async (req, reply) => {
    const n = req.body?.minCount;
    if (typeof n !== "number" || n < 0) return reply.code(400).send({ error: "minCount >= 0 required" });
    return ctx.communityAdmin.setReactionMinCount(n);
  });
  app.post<{ Body: { hours?: number } }>("/api/admin/cooldown-hours", { preHandler: requireAdmin }, async (req, reply) => {
    const h = req.body?.hours;
    if (typeof h !== "number" || !Number.isInteger(h) || h < 1 || h > 168) return reply.code(400).send({ error: "hours must be an integer from 1 to 168" });
    return ctx.communityAdmin.setCooldownHours(h);
  });

  // ---- Web Access (proxied to the Access Service; default OFF) ----
  app.get("/api/admin/access", { preHandler: requireAdmin }, async () => {
    try {
      return { reachable: true, status: await ctx.accessAdmin.status() };
    } catch {
      return { reachable: false, status: null };
    }
  });
  app.post<{ Body: { on?: boolean } }>("/api/admin/access/enabled", { preHandler: requireAdmin }, async (req, reply) => {
    if (typeof req.body?.on !== "boolean") return reply.code(400).send({ error: "on (boolean) required" });
    return ctx.accessAdmin.setEnabled(req.body.on);
  });
  app.get("/api/admin/access/journal", { preHandler: requireAdmin }, async () => ctx.accessAdmin.journal());
}
