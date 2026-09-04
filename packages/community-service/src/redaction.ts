// The identity-free boundary of the Community process (spec §29.5):
//   - every request gets a FRESH Community-local request id (never one from Core);
//   - a request carrying a Cookie, an ordinary Authorization header, or any
//     account-derived header is refused outright — the reverse proxy strips
//     them; the service refuses them as well, so a misconfigured edge cannot
//     leak an account correlation in;
//   - operational logs carry route class, status and duration only — no
//     bodies, no query strings, no authorTag, no keys.

import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";

export const FORBIDDEN_HEADERS = ["cookie", "authorization", "x-honey-account", "x-honey-user", "x-request-id", "x-correlation-id", "x-honey-session"] as const;

export interface LogLine {
  id: string;
  route: string;
  status: number;
  ms: number;
}

export function installIdentityFreeBoundary(
  app: FastifyInstance,
  opts: { log?: ((line: LogLine) => void) | undefined; allowInternal?: ((path: string) => boolean) | undefined } = {},
): void {
  app.addHook("onRequest", async (req, reply) => {
    (req as unknown as { communityId: string; startedAt: number }).communityId = randomUUID();
    (req as unknown as { communityId: string; startedAt: number }).startedAt = Date.now();
    const internal = opts.allowInternal?.(req.url) ?? false;
    for (const h of FORBIDDEN_HEADERS) {
      if (h === "authorization" && internal) continue; // the internal admin route uses its own secret header
      if (req.headers[h] !== undefined) {
        await reply.code(400).send({ error: "identity_material_refused", header: h });
        return;
      }
    }
  });
  app.addHook("onResponse", async (req, reply) => {
    const r = req as unknown as { communityId: string; startedAt: number };
    // Route class only: the pattern, never the concrete URL (ids, queries).
    const route = req.routeOptions?.url ?? "unmatched";
    opts.log?.({ id: r.communityId, route, status: reply.statusCode, ms: Date.now() - r.startedAt });
  });
}

/** Allowlist projection of a stored post for public and admin DTOs: no authorTag, no keys, no nonce. */
export const PUBLIC_POST_FIELDS = ["id", "primary_entity_type", "primary_entity_id", "body", "rating", "provenance", "published_day"] as const;
export const FORBIDDEN_DTO_FIELDS = ["author_tag", "authorTag", "posting_public_key", "postingPublicKey", "control_public_key", "controlPublicKey", "client_nonce", "content_hash", "reactor_tag", "reporter_tag"] as const;

export function assertNoIdentityFields(value: unknown): void {
  const text = JSON.stringify(value);
  for (const f of FORBIDDEN_DTO_FIELDS) {
    if (text.includes(`"${f}"`)) throw new Error(`DTO leaks ${f}`);
  }
}
