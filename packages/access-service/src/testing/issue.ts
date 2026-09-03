// Test-only capability issuance: the same envelope Core produces (Ed25519
// over JCS(body), portal session HPKE-sealed to the service key), built
// from throwaway keys so the service can be exercised without Core.

import { createPublicKey, generateKeyPairSync, sign as edSign, type KeyObject } from "node:crypto";
import { canonicalBytes, toBase64Url, utf8 } from "@honey/shared/community-v2";
import { newSealingKeyPair, sealTo, type AccessCapability, type AccessCapabilityBody, type SealedPortalSession } from "@honey/shared/access";

export interface TestIssuer {
  keys: { core: { keyId: string; publicKey: string }; sealing: { publicKey: string; privateKey: string } };
  issue(input: { subject: string; session: SealedPortalSession; now: number; ttlMs?: number; tamper?: boolean }): Promise<string>;
}

export async function makeTestIssuer(): Promise<TestIssuer> {
  const { privateKey } = generateKeyPairSync("ed25519");
  const spki = createPublicKey(privateKey).export({ format: "der", type: "spki" }) as Buffer;
  const core = { keyId: "core-test", publicKey: toBase64Url(new Uint8Array(spki)) };
  const sealing = await newSealingKeyPair();
  return {
    keys: { core, sealing },
    async issue(input) {
      const capabilityId = "cap_" + toBase64Url(crypto.getRandomValues(new Uint8Array(12)));
      const sealed = await sealTo(sealing.publicKey, capabilityId, utf8(JSON.stringify(input.session)));
      const body: AccessCapabilityBody = {
        version: 1,
        audience: "honey-web-access",
        capabilityId,
        subject: input.subject,
        schoolId: input.session.schoolId,
        portalStudentId: input.session.portalStudentId,
        issuedAt: input.now,
        expiresAt: input.now + (input.ttlMs ?? 10 * 60_000),
        sealedPortalSession: { ...sealed, keyId: sealing.publicKey.slice(0, 12) },
      };
      const signature = toBase64Url(new Uint8Array(edSign(null, Buffer.from(canonicalBytes(body as never)), privateKey as KeyObject)));
      if (input.tamper) body.subject = body.subject + "x";
      const envelope: AccessCapability = { body, keyId: core.keyId, signature };
      return toBase64Url(utf8(JSON.stringify(envelope)));
    },
  };
}
