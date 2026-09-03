// Access capabilities (spec §17): Core signs the envelope with its Ed25519
// signing key; the portal session inside is HPKE-sealed to THIS service's
// key. The service verifies signature, audience and expiry, opens the sealed
// session in memory only, and never persists the token.

import { createPublicKey, verify as edVerify } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { canonicalBytes, fromBase64Url, fromUtf8 } from "@honey/shared/community-v2";
import { newSealingKeyPair, openSealed, type AccessCapability, type SealedPortalSession } from "@honey/shared/access";

export interface CoreSigningDescriptor {
  keyId: string;
  /** Ed25519 public key, SPKI DER base64url. */
  publicKey: string;
}

export interface VerifiedCapability {
  capabilityId: string;
  subject: string;
  schoolId: string;
  portalStudentId: string;
  expiresAt: number;
  session: SealedPortalSession;
}

export type CapabilityError = "capability_invalid" | "capability_expired";

const AUDIENCE = "honey-web-access";

export class CapabilityVerifier {
  private coreKeys = new Map<string, ReturnType<typeof createPublicKey>>();
  private loadedAt = 0;
  private readonly sealing: { publicKey: string; privateKey: string };

  constructor(
    private readonly keysDir: string,
    fixed?: { core?: CoreSigningDescriptor; sealing?: { publicKey: string; privateKey: string } },
  ) {
    if (fixed?.core) this.coreKeys.set(fixed.core.keyId, createPublicKey({ key: Buffer.from(fromBase64Url(fixed.core.publicKey)), format: "der", type: "spki" }));
    this.sealing = fixed?.sealing ?? CapabilityVerifier.loadOrCreateSealing(keysDir);
    if (!fixed) mkdirSync(keysDir, { recursive: true });
  }

  /** The HPKE key pair Core seals portal sessions to; created once, private half 0600. */
  private static loadOrCreateSealing(keysDir: string): { publicKey: string; privateKey: string } {
    mkdirSync(keysDir, { recursive: true, mode: 0o700 });
    const privPath = join(keysDir, "access-sealing.private.json");
    if (existsSync(privPath)) return JSON.parse(readFileSync(privPath, "utf8")) as { publicKey: string; privateKey: string };
    // Synchronous creation is fine at startup; the async generator runs once.
    throw new Error("access sealing key missing — call CapabilityVerifier.ensureSealingKey first");
  }

  static async ensureSealingKey(keysDir: string): Promise<{ publicKey: string; privateKey: string }> {
    mkdirSync(keysDir, { recursive: true, mode: 0o700 });
    const privPath = join(keysDir, "access-sealing.private.json");
    const pubPath = join(keysDir, "access-sealing.public.json");
    let pair: { publicKey: string; privateKey: string };
    if (existsSync(privPath)) {
      pair = JSON.parse(readFileSync(privPath, "utf8")) as { publicKey: string; privateKey: string };
    } else {
      pair = await newSealingKeyPair();
      writeFileSync(privPath, JSON.stringify(pair), { mode: 0o600 });
    }
    writeFileSync(pubPath, JSON.stringify({ keyId: pair.publicKey.slice(0, 12), publicKey: pair.publicKey }, null, 2) + "\n");
    return pair;
  }

  get sealingPublicKey(): string {
    return this.sealing.publicKey;
  }

  private coreKey(keyId: string): ReturnType<typeof createPublicKey> | null {
    if (!this.coreKeys.has(keyId) || Date.now() - this.loadedAt > 5 * 60_000) {
      const path = join(this.keysDir, "core-signing.public.json");
      if (existsSync(path)) {
        try {
          const d = JSON.parse(readFileSync(path, "utf8")) as CoreSigningDescriptor;
          this.coreKeys.set(d.keyId, createPublicKey({ key: Buffer.from(fromBase64Url(d.publicKey)), format: "der", type: "spki" }));
        } catch {
          /* keep what we have */
        }
      }
      this.loadedAt = Date.now();
    }
    return this.coreKeys.get(keyId) ?? null;
  }

  async verify(raw: string | undefined, now: number): Promise<{ ok: true; capability: VerifiedCapability } | { ok: false; error: CapabilityError }> {
    if (typeof raw !== "string" || raw.length > 8192) return { ok: false, error: "capability_invalid" };
    let cap: AccessCapability;
    try {
      cap = JSON.parse(fromUtf8(fromBase64Url(raw))) as AccessCapability;
    } catch {
      return { ok: false, error: "capability_invalid" };
    }
    const b = cap?.body;
    if (!b || b.version !== 1 || b.audience !== AUDIENCE || typeof b.capabilityId !== "string" || typeof b.subject !== "string" || typeof b.expiresAt !== "number" || typeof cap.signature !== "string") {
      return { ok: false, error: "capability_invalid" };
    }
    const key = this.coreKey(cap.keyId);
    if (!key) return { ok: false, error: "capability_invalid" };
    let valid = false;
    try {
      valid = edVerify(null, Buffer.from(canonicalBytes(b as never)), key, Buffer.from(fromBase64Url(cap.signature)));
    } catch {
      valid = false;
    }
    if (!valid) return { ok: false, error: "capability_invalid" };
    if (b.expiresAt <= now || b.issuedAt > now + 60_000) return { ok: false, error: "capability_expired" };
    let session: SealedPortalSession;
    try {
      const s = b.sealedPortalSession;
      const pt = await openSealed(this.sealing.privateKey, b.capabilityId, s.enc, s.ciphertext);
      session = JSON.parse(fromUtf8(pt)) as SealedPortalSession;
      if (typeof session.token !== "string" || session.portalStudentId !== b.portalStudentId || session.schoolId !== b.schoolId) return { ok: false, error: "capability_invalid" };
    } catch {
      return { ok: false, error: "capability_invalid" };
    }
    return { ok: true, capability: { capabilityId: b.capabilityId, subject: b.subject, schoolId: b.schoolId, portalStudentId: b.portalStudentId, expiresAt: b.expiresAt, session } };
  }
}
