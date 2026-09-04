import type { FastifyInstance } from "fastify";
import type { PairingDelivery, VaultPutRequest, VaultWrapper } from "@honey/shared/community-v2";
import type { AppContext } from "../context.js";

// Control Vault surface (spec §35, §38): ciphertext in, ciphertext out. Core
// authenticates the account to locate the record and never sees a root.

const B64URL = /^[A-Za-z0-9_-]*$/;
const MAX_CIPHERTEXT = 64 * 1024;

function validWrappers(value: unknown): value is VaultWrapper[] {
  if (!Array.isArray(value) || value.length > 16) return false;
  return value.every((w) => {
    if (!w || typeof w !== "object") return false;
    const x = w as Record<string, unknown>;
    if (x.type === "passkey_prf") return typeof x.credentialId === "string" && typeof x.wrappedR === "string" && typeof x.iv === "string";
    if (x.type === "recovery_phrase") return x.format === "words12-v1" && typeof x.wrappedR === "string" && typeof x.iv === "string";
    return false;
  });
}

export function registerVaultRoutes(app: FastifyInstance, ctx: AppContext): void {
  app.get("/api/vault", { preHandler: ctx.requireAuth }, async (req, reply) => {
    void reply.header("cache-control", "no-store");
    const record = ctx.vault.get(ctx.userOf(req).honey_id);
    if (!record) return reply.code(404).send({ error: "no_vault" });
    return record;
  });

  app.put<{ Body: Partial<VaultPutRequest> }>("/api/vault", { preHandler: ctx.requireAuth }, async (req, reply) => {
    const b = req.body ?? {};
    if (
      typeof b.vaultId !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(b.vaultId) ||
      typeof b.baseRevision !== "number" || !Number.isInteger(b.baseRevision) || b.baseRevision < 0 ||
      typeof b.iv !== "string" || !B64URL.test(b.iv) ||
      typeof b.ciphertext !== "string" || !B64URL.test(b.ciphertext) || b.ciphertext.length > MAX_CIPHERTEXT ||
      !validWrappers(b.wrappers)
    ) {
      return reply.code(400).send({ error: "vault_request_invalid" });
    }
    const result = ctx.vault.put(ctx.userOf(req).honey_id, {
      vaultId: b.vaultId, baseRevision: b.baseRevision, iv: b.iv, ciphertext: b.ciphertext, wrappers: b.wrappers,
    });
    if (!result.ok) return reply.code(409).send(result);
    return result;
  });

  app.delete("/api/vault", { preHandler: ctx.requireAuth }, async (req) => {
    ctx.vault.delete(ctx.userOf(req).honey_id);
    return { ok: true };
  });

  // ---- pairing relay (same account on both devices) ----

  app.post<{ Body: { recipientPublicKey?: string } }>("/api/vault/pairing", { preHandler: ctx.requireAuth }, async (req, reply) => {
    const pk = req.body?.recipientPublicKey;
    if (typeof pk !== "string" || !B64URL.test(pk) || pk.length < 40 || pk.length > 48) return reply.code(400).send({ error: "public_key_invalid" });
    return ctx.vault.offer(ctx.userOf(req).honey_id, pk);
  });

  app.get<{ Params: { id: string } }>("/api/vault/pairing/:id", { preHandler: ctx.requireAuth }, async (req, reply) => {
    const offer = ctx.vault.readOffer(ctx.userOf(req).honey_id, req.params.id);
    if (!offer) return reply.code(404).send({ error: "pairing_not_found" });
    return offer;
  });

  app.post<{ Params: { id: string }; Body: Partial<PairingDelivery> }>("/api/vault/pairing/:id/deliver", { preHandler: ctx.requireAuth }, async (req, reply) => {
    const { enc, ciphertext } = req.body ?? {};
    if (typeof enc !== "string" || typeof ciphertext !== "string" || !B64URL.test(enc) || !B64URL.test(ciphertext) || ciphertext.length > 4096) {
      return reply.code(400).send({ error: "delivery_invalid" });
    }
    const ok = ctx.vault.deliver(ctx.userOf(req).honey_id, { pairingId: req.params.id, enc, ciphertext });
    if (!ok) return reply.code(404).send({ error: "pairing_not_found" });
    return { ok: true };
  });

  app.get<{ Params: { id: string } }>("/api/vault/pairing/:id/delivery", { preHandler: ctx.requireAuth }, async (req, reply) => {
    void reply.header("cache-control", "no-store");
    const delivery = ctx.vault.claim(ctx.userOf(req).honey_id, req.params.id);
    if (!delivery) return reply.code(404).send({ error: "pairing_pending" });
    return delivery;
  });

  /** Same-device hand-off: the source seals R to a key whose private half it puts in the link fragment. */
  app.post<{ Body: { recipientPublicKey?: string; enc?: string; ciphertext?: string } }>("/api/vault/handoff", { preHandler: ctx.requireAuth }, async (req, reply) => {
    const { recipientPublicKey, enc, ciphertext } = req.body ?? {};
    if (
      typeof recipientPublicKey !== "string" || !B64URL.test(recipientPublicKey) ||
      typeof enc !== "string" || typeof ciphertext !== "string" || !B64URL.test(enc) || !B64URL.test(ciphertext) || ciphertext.length > 4096
    ) {
      return reply.code(400).send({ error: "handoff_invalid" });
    }
    return ctx.vault.handoff(ctx.userOf(req).honey_id, recipientPublicKey, { enc, ciphertext });
  });
}
