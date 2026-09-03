// Core's Web Access capability signer (spec §17). One Ed25519 key in the
// keys directory (`core-signing.private.json`, 0600) whose public half is
// written beside it for the Access Service to read. The portal session is
// sealed to the Access Service's HPKE public key, also read from that
// directory: the capability crosses the browser opaque to it.

import { createPrivateKey, createPublicKey, generateKeyPairSync, sign as edSign, type KeyObject } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { canonicalBytes, toBase64Url, utf8 } from "@honey/shared/community-v2";
import { sealTo, type AccessCapability, type AccessCapabilityBody, type SealedPortalSession } from "@honey/shared/access";

export const CAPABILITY_TTL_MS = 10 * 60_000;

interface StoredKey {
  keyId: string;
  /** PKCS8 DER base64url. */
  privateKey: string;
}

export class AccessCapabilitySigner {
  private constructor(
    readonly keyId: string,
    private readonly privateKey: KeyObject,
    private readonly keysDir: string,
  ) {}

  /** Load or create the signing key; publish the public descriptor. */
  static load(keysDir: string): AccessCapabilitySigner {
    mkdirSync(keysDir, { recursive: true, mode: 0o700 });
    const privPath = join(keysDir, "core-signing.private.json");
    let stored: StoredKey;
    if (existsSync(privPath)) {
      stored = JSON.parse(readFileSync(privPath, "utf8")) as StoredKey;
    } else {
      const { privateKey } = generateKeyPairSync("ed25519");
      const der = privateKey.export({ format: "der", type: "pkcs8" }) as Buffer;
      stored = { keyId: "core-" + toBase64Url(new Uint8Array(der.subarray(-8))), privateKey: toBase64Url(new Uint8Array(der)) };
      writeFileSync(privPath, JSON.stringify(stored), { mode: 0o600 });
    }
    const privateKey = createPrivateKey({ key: Buffer.from(stored.privateKey, "base64url"), format: "der", type: "pkcs8" });
    const publicDer = createPublicKey(privateKey).export({ format: "der", type: "spki" }) as Buffer;
    writeFileSync(join(keysDir, "core-signing.public.json"), JSON.stringify({ keyId: stored.keyId, publicKey: toBase64Url(new Uint8Array(publicDer)) }, null, 2) + "\n");
    return new AccessCapabilitySigner(stored.keyId, privateKey, keysDir);
  }

  /** The Access Service's sealing key, or null while that service has never started. */
  accessSealingKey(): { keyId: string; publicKey: string } | null {
    const path = join(this.keysDir, "access-sealing.public.json");
    if (!existsSync(path)) return null;
    try {
      return JSON.parse(readFileSync(path, "utf8")) as { keyId: string; publicKey: string };
    } catch {
      return null;
    }
  }

  async issue(input: { subject: string; schoolId: string; session: SealedPortalSession; now: number }): Promise<{ capability: string; expiresAt: number } | null> {
    const sealing = this.accessSealingKey();
    if (!sealing) return null;
    const capabilityId = "cap_" + toBase64Url(crypto.getRandomValues(new Uint8Array(12)));
    const expiresAt = Math.min(input.now + CAPABILITY_TTL_MS, input.session.tokenExpiresAt);
    const sealed = await sealTo(sealing.publicKey, capabilityId, utf8(JSON.stringify(input.session)));
    const body: AccessCapabilityBody = {
      version: 1,
      audience: "honey-web-access",
      capabilityId,
      subject: input.subject,
      schoolId: input.schoolId,
      portalStudentId: input.session.portalStudentId,
      issuedAt: input.now,
      expiresAt,
      sealedPortalSession: { ...sealed, keyId: sealing.keyId },
    };
    const signature = toBase64Url(new Uint8Array(edSign(null, Buffer.from(canonicalBytes(body as never)), this.privateKey)));
    const envelope: AccessCapability = { body, keyId: this.keyId, signature };
    return { capability: toBase64Url(utf8(JSON.stringify(envelope))), expiresAt };
  }
}
