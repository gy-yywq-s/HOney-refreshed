// Content-bound publication pass (spec §32.3). Issued by the check route
// after moderation, verified by publish. Binds: body hash, canonical context
// hash, school/year, posting + control public keys, post nonce, eligibility
// reservation (token hash), policy version, a single-use nonce, expiry.
// Any change to body, context or keys invalidates it. HMAC-SHA256 with
// Community's own key — the issuer and the verifier are the same process.

import { createHash, createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { canonicalize, type SignedPostEnvelopeV2 } from "@honey/shared/community-v2";

export interface PassPayload {
  bodyHash: string;
  contextHash: string;
  schoolId: string;
  academicYear: string;
  postingPublicKey: string;
  controlPublicKey: string;
  postNonce: string;
  tokenHash: string;
  policyVersion: number;
  nonce: string;
  expiresAt: number;
}

export function bodyHashOf(body: string, rating: number | null): string {
  return createHash("sha256").update(JSON.stringify({ body, rating })).digest("hex");
}

export function contextHashOf(envelope: SignedPostEnvelopeV2): string {
  return createHash("sha256")
    .update(canonicalize({ primary: envelope.primaryEntity, contexts: envelope.contexts } as never))
    .digest("hex");
}

function payloadString(p: PassPayload): string {
  return canonicalize(p as never);
}

export function issuePass(fields: Omit<PassPayload, "nonce" | "expiresAt">, key: Buffer, ttlMs: number, now: number): string {
  const payload: PassPayload = { ...fields, nonce: randomBytes(16).toString("hex"), expiresAt: now + ttlMs };
  const signature = createHmac("sha256", key).update(payloadString(payload)).digest("hex");
  return Buffer.from(JSON.stringify({ p: payload, s: signature })).toString("base64url");
}

export function openPass(pass: string, key: Buffer, now: number): PassPayload | null {
  let parsed: { p: PassPayload; s: string };
  try {
    parsed = JSON.parse(Buffer.from(pass, "base64url").toString("utf8")) as { p: PassPayload; s: string };
  } catch {
    return null;
  }
  if (!parsed?.p || typeof parsed.s !== "string") return null;
  if (typeof parsed.p.expiresAt !== "number" || parsed.p.expiresAt <= now) return null;
  const expected = Buffer.from(createHmac("sha256", key).update(payloadString(parsed.p)).digest("hex"), "hex");
  const given = Buffer.from(parsed.s.padEnd(64, "0").slice(0, 64), "hex");
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
  return parsed.p;
}
