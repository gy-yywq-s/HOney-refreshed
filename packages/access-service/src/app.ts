// The Access Service HTTP surface (spec §20): a capability header on every
// public route, a commit secret on commit, NDJSON progress, and a loopback
// admin surface behind the internal secret. Logs carry a route class and a
// status — never a subject, a capability, a token or an upstream body.

import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from "fastify";
import type { AccessAdminStatus, AccessProgressEvent, ApplyPermitInput, PrepareOpenInput } from "@honey/shared/access";
import { openAccessDatabase, type DatabaseSync } from "./access-db.js";
import { CapabilityVerifier, type VerifiedCapability } from "./capability.js";
import type { AccessConfig } from "./config.js";
import { AccessError } from "./errors.js";
import { LatencyModel } from "./latency.js";
import { OperationStore } from "./operation-store.js";
import { AccessEngine } from "./operations.js";
import { AccessPortalClient } from "./portal-client.js";
import { RuntimePolicy } from "./runtime-policy.js";

export interface AccessAppOptions {
  config: AccessConfig;
  /** Tests: a fixed Core public key + sealing pair instead of the keys directory. */
  keys?: { core: { keyId: string; publicKey: string }; sealing: { publicKey: string; privateKey: string } };
  fetchImpl?: typeof fetch;
  portalTimeoutMs?: number;
  now?: () => number;
}

export interface AccessApp {
  app: FastifyInstance;
  db: DatabaseSync;
  engine: AccessEngine;
  policy: RuntimePolicy;
  store: OperationStore;
  verifier: CapabilityVerifier;
  close(): Promise<void>;
}

const CAPABILITY_HEADER = "access-capability";
const COMMIT_HEADER = "access-commit";

export async function buildAccessApp(opts: AccessAppOptions): Promise<AccessApp> {
  const { config } = opts;
  if (!opts.keys) await CapabilityVerifier.ensureSealingKey(config.keysDir);
  const verifier = new CapabilityVerifier(config.keysDir, opts.keys);
  const db = openAccessDatabase(config.dbPath);
  const now = opts.now ?? (() => Date.now());
  const store = new OperationStore(db, config.serviceVersion);
  const recovered = store.recoverAfterRestart(now());
  const latency = new LatencyModel(db, config.serviceVersion);
  const policy = new RuntimePolicy(db);
  const portal = new AccessPortalClient({ baseUrl: config.portalBaseUrl, allowedOrigins: config.allowedEgressOrigins, ...(opts.fetchImpl ? { fetchImpl: opts.fetchImpl } : {}), ...(opts.portalTimeoutMs ? { timeoutMs: opts.portalTimeoutMs } : {}) });
  const engine = new AccessEngine({ store, latency, policy, portal, serviceVersion: config.serviceVersion, now });

  const app = Fastify({
    logger: false,
    bodyLimit: 16 * 1024,
    forceCloseConnections: true,
  });
  if (recovered > 0) app.log.warn({ recovered }, "operations in flight at restart marked OUTCOME_UNKNOWN");

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof AccessError) return reply.code(err.status).send(err.toJSON());
    const status = (err as { statusCode?: number }).statusCode;
    if (status && status >= 400 && status < 500) return reply.code(status).send({ error: "bad_request" });
    return reply.code(500).send({ error: "service_unavailable" });
  });

  // ---- capability guard ---------------------------------------------------
  const CAP = Symbol("capability");
  const withCapability = async (req: FastifyRequest, reply: FastifyReply) => {
    // Identity headers never reach this process (the edge strips them); a
    // stray Cookie/Authorization means a misrouted request — refuse it.
    if (req.headers.cookie || req.headers.authorization) return reply.code(400).send({ error: "capability_invalid" });
    const raw = req.headers[CAPABILITY_HEADER];
    const result = await verifier.verify(Array.isArray(raw) ? raw[0] : raw, now());
    if (!result.ok) return reply.code(401).send({ error: result.error });
    (req as unknown as Record<symbol, VerifiedCapability>)[CAP] = result.capability;
  };
  const capOf = (req: FastifyRequest): VerifiedCapability => (req as unknown as Record<symbol, VerifiedCapability>)[CAP]!;

  app.get("/access/health", async () => ({ ok: true, serviceVersion: config.serviceVersion }));

  app.get("/access/bootstrap", { preHandler: withCapability }, async (req) => engine.bootstrap(capOf(req)));

  app.post<{ Body: PrepareOpenInput }>("/access/operations/open/prepare", { preHandler: withCapability }, async (req) => engine.prepareOpen(capOf(req), req.body ?? ({} as PrepareOpenInput)));

  app.post<{ Body: ApplyPermitInput }>("/access/operations/permit/prepare", { preHandler: withCapability }, async (req) => engine.preparePermit(capOf(req), req.body ?? ({} as ApplyPermitInput)));

  app.post<{ Body: { recordId: number; clientNonce: string } }>("/access/operations/withdraw/prepare", { preHandler: withCapability }, async (req) => engine.prepareWithdraw(capOf(req), req.body ?? { recordId: NaN, clientNonce: "" }));

  app.post<{ Params: { id: string } }>("/access/operations/:id/commit", { preHandler: withCapability }, async (req, reply) => {
    const secretRaw = req.headers[COMMIT_HEADER];
    const secret = Array.isArray(secretRaw) ? secretRaw[0] : secretRaw;
    if (typeof secret !== "string" || !secret) throw new AccessError("commit_secret_invalid");
    const events = engine.commit(capOf(req), req.params.id, secret); // throws before any byte when the claim fails
    reply.raw.writeHead(200, { "content-type": "application/x-ndjson", "cache-control": "no-store", "x-accel-buffering": "no" });
    reply.hijack();
    try {
      for await (const event of events as AsyncIterable<AccessProgressEvent>) {
        if (reply.raw.destroyed) break; // the dispatch continues regardless
        reply.raw.write(JSON.stringify(event) + "\n");
      }
    } finally {
      if (!reply.raw.destroyed) reply.raw.end();
    }
  });

  app.get<{ Params: { id: string } }>("/access/operations/:id", { preHandler: withCapability }, async (req) => engine.status(capOf(req), req.params.id));

  // ---- internal admin (loopback + secret; the edge 404s /internal/*) ------
  const requireInternal = async (req: FastifyRequest, reply: FastifyReply) => {
    const ip = req.socket.remoteAddress ?? "";
    const loopback = ip === "127.0.0.1" || ip === "::1" || ip === "::ffff:127.0.0.1";
    if (!loopback || req.headers["x-honey-internal"] !== config.internalSecret) return reply.code(404).send({ error: "not_found" });
  };

  app.get("/internal/admin/status", { preHandler: requireInternal }, async (): Promise<AccessAdminStatus> => {
    const dayAgo = now() - 24 * 3600 * 1000;
    return {
      enabled: policy.enabled(),
      healthy: true,
      serviceVersion: config.serviceVersion,
      activeOperations: store.countActive(),
      typicalOpen: latency.eta("open_gate").label,
      unknownToday: store.countUnknownSince(dayAgo),
      egress: { portalOrigin: config.allowedEgressOrigins[0] ?? "" },
    };
  });

  app.post<{ Body: { on?: boolean } }>("/internal/admin/enabled", { preHandler: requireInternal }, async (req, reply) => {
    if (typeof req.body?.on !== "boolean") return reply.code(400).send({ error: "on (boolean) required" });
    policy.setEnabled(req.body.on);
    return { ok: true, enabled: policy.enabled() };
  });

  app.get("/internal/admin/journal", { preHandler: requireInternal }, async () => ({ operations: store.recent(50) }));

  return {
    app,
    db,
    engine,
    policy,
    store,
    verifier,
    async close() {
      await app.close();
      // Let requests already on the wire record their outcome before the journal closes.
      await engine.drain(15_000);
      db.close();
    },
  };
}
