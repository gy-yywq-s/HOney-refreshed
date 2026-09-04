import Fastify, { type FastifyInstance } from "fastify";
import { portalWeekIndex } from "@honey/shared";
import type {
  CheckRequestV2,
  FeedRequestV2,
  FeedUpdatesRequestV2,
  FromMyClassesRequestV2,
  IssuerDescriptor,
  MineRequest,
  PublishRequestV2,
  ReactRequestV2,
  RegisterReactorRequest,
  ReportRequestV2,
  RevokeRequest,
} from "@honey/shared/community-v2";
import { loadCommunityConfig, type CommunityConfig } from "./config.js";
import { openCommunityDatabase, type DatabaseSync } from "./community-db.js";
import { FeedService } from "./feed.js";
import { OwnershipService } from "./ownership.js";
import { PublicationService } from "./publish.js";
import { ReactionService } from "./reactions.js";
import { installIdentityFreeBoundary, type LogLine } from "./redaction.js";
import { CommunitySettings } from "./settings.js";
import { IssuerKeys, TokenRedemption } from "./token-redemption.js";
import { defaultLlmRunner } from "./moderation/index.js";
import { registerAdminRoutes } from "./admin.js";

// HOney Community — the process that stores anonymous posts and cannot
// resolve an account (spec §29). It imports nothing from the Core package,
// opens only community.sqlite, and refuses any request that carries session
// or account material.

export interface CommunityAppOptions {
  config?: Partial<CommunityConfig>;
  dbPath?: string;
  /** A fixed issuer descriptor for tests (production reads the file Core writes). */
  issuer?: IssuerDescriptor;
  now?: () => number;
  log?: (line: LogLine) => void;
}

export interface CommunityContext {
  db: DatabaseSync;
  config: CommunityConfig;
  settings: CommunitySettings;
  redemption: TokenRedemption;
  publication: PublicationService;
  feed: FeedService;
  ownership: OwnershipService;
  reactions: ReactionService;
}

const BODY_LIMIT = 64 * 1024;

export function buildCommunityApp(opts: CommunityAppOptions = {}): FastifyInstance & { ctx: CommunityContext } {
  const config: CommunityConfig = { ...loadCommunityConfig(), ...opts.config };
  if (opts.dbPath) config.dbPath = opts.dbPath;
  const now = opts.now ?? Date.now;
  const db = openCommunityDatabase(config.dbPath);
  const settings = new CommunitySettings(db, config.sealKey, config.openRouterApiKey);
  const issuers = new IssuerKeys(config.issuerPublicPath, opts.issuer);
  const redemption = new TokenRedemption(db, issuers, () => portalWeekIndex(new Date(now())), now);
  const llm = defaultLlmRunner(() => settings.llmConfig());
  const publication = new PublicationService(db, settings, redemption, config.schoolId, config.sealKey, llm, now);
  const feed = new FeedService(db, settings, config.schoolId, config.sealKey);
  const ownership = new OwnershipService(db, config.schoolId, now);
  const reactions = new ReactionService(db, settings, redemption, config.schoolId, llm, now);
  const ctx: CommunityContext = { db, config, settings, redemption, publication, feed, ownership, reactions };

  const app = Fastify({ logger: false, bodyLimit: BODY_LIMIT, trustProxy: false }) as unknown as FastifyInstance & { ctx: CommunityContext };
  app.ctx = ctx;
  installIdentityFreeBoundary(app, { log: opts.log, allowInternal: (url) => url.startsWith("/internal/") });
  app.addContentTypeParser("application/json", { parseAs: "string" }, (_req, body, done) => {
    const text = (body as string).trim();
    if (!text) return done(null, {});
    try {
      done(null, JSON.parse(text));
    } catch (err) {
      done(err as Error, undefined);
    }
  });

  app.get("/community/health", async () => ({ status: "ok", service: "honey-community" }));

  // ---- publication (identity-free) ----
  app.post<{ Body: CheckRequestV2 }>("/community/v2/check", async (req, reply) => {
    const result = await ctx.publication.check(req.body);
    if (!result.ok) return reply.code(422).send({ error: result.error });
    return result.response;
  });
  app.post<{ Body: PublishRequestV2 }>("/community/v2/publish", async (req, reply) => {
    const result = await ctx.publication.publish(req.body);
    if (!result.ok) return reply.code(422).send({ error: result.error });
    return result.response;
  });

  // ---- reads ----
  app.post<{ Body: FeedRequestV2 }>("/community/v2/feed", async (req, reply) => {
    const b = req.body ?? ({} as FeedRequestV2);
    const result = ctx.feed.feedPage({ ...b, scope: b.scope === "school" ? "school" : "my_classes" });
    if (!result.ok) return reply.code(400).send({ error: result.error });
    return result.page;
  });
  app.post<{ Body: FeedUpdatesRequestV2 }>("/community/v2/feed/updates", async (req, reply) => {
    const b = req.body ?? ({} as FeedUpdatesRequestV2);
    if (typeof b.head !== "string") return reply.code(400).send({ error: "head_required" });
    const result = ctx.feed.feedUpdates({ ...b, scope: b.scope === "school" ? "school" : "my_classes" });
    if (!result.ok) return reply.code(400).send({ error: result.error });
    return { newItemsAvailable: result.newItemsAvailable };
  });
  app.post<{ Body: FromMyClassesRequestV2 }>("/community/v2/from-my-classes", async (req) => {
    const b = req.body ?? ({} as FromMyClassesRequestV2);
    const opts: { before?: number; limit?: number } = {};
    if (typeof b.before === "number") opts.before = b.before;
    if (typeof b.limit === "number") opts.limit = b.limit;
    return { experiences: ctx.feed.fromMyClasses(b.exposure ?? { teachers: [], courses: [], lessons: [] }, opts) };
  });
  app.get<{ Querystring: { q?: string } }>("/community/v2/search", async (req) => {
    const q = req.query.q ?? "";
    return { q: q.trim().slice(0, 60), experiences: ctx.feed.search(q) };
  });
  app.get<{ Querystring: { entityKey?: string } }>("/community/v2/stats", async (req, reply) => {
    if (!req.query.entityKey) return reply.code(400).send({ error: "entityKey_required" });
    return ctx.feed.stats(req.query.entityKey);
  });

  // ---- ownership ----
  app.post("/community/v2/mine/challenge", async () => ctx.ownership.challenge("honey/v2/mine"));
  app.post<{ Body: MineRequest }>("/community/v2/mine", async (req, reply) => {
    const result = ctx.ownership.mine(req.body);
    if (!result.ok) return reply.code(422).send({ error: result.error });
    return { experiences: result.experiences };
  });
  app.post<{ Params: { id: string } }>("/community/v2/posts/:id/revoke/challenge", async () => ctx.ownership.challenge("honey/v2/revoke"));
  app.post<{ Params: { id: string }; Body: RevokeRequest }>("/community/v2/posts/:id/revoke", async (req, reply) => {
    const result = ctx.ownership.revoke(req.params.id, req.body);
    if (!result.ok) return reply.code(result.error === "not_found" ? 404 : 422).send({ error: result.error });
    return { ok: true };
  });

  // ---- reactions / reports ----
  app.post<{ Body: RegisterReactorRequest }>("/community/v2/reactors/register", async (req, reply) => {
    const result = await ctx.reactions.register(req.body);
    if (!result.ok) return reply.code(422).send({ error: result.error });
    return { ok: true };
  });
  app.post<{ Params: { id: string }; Body: ReactRequestV2 }>("/community/v2/posts/:id/react", async (req, reply) => {
    const result = ctx.reactions.react(req.params.id, req.body);
    if (!result.ok) return reply.code(result.error === "not_found" ? 404 : 422).send({ error: result.error });
    return { ok: true, value: result.value, reactions: result.reactions };
  });
  app.post<{ Params: { id: string }; Body: ReportRequestV2 }>("/community/v2/posts/:id/report", async (req, reply) => {
    const result = await ctx.reactions.report(req.params.id, req.body);
    if (!result.ok) return reply.code(result.error === "not_found" ? 404 : 422).send({ error: result.error });
    return { ok: true };
  });

  registerAdminRoutes(app, { db, settings, publication, reactions, internalSecret: config.internalSecret });

  app.setNotFoundHandler((_req, reply) => reply.code(404).send({ error: "not_found" }));
  app.addHook("onClose", async () => {
    db.close();
  });
  return app;
}
