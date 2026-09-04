import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { bytesEqual, fromBase64Url, fromHex, randomBytes, toBase64Url, utf8 } from "./bytes.js";
import { canonicalize } from "./canonical-json.js";
import { authorTag, postControlKeyPair, postingKeyPair, reactionKeyPair, schoolSalt, signStatement, verifyStatement } from "./derivation.js";
import { activeRoot, initialPayload, mergePayloads, newRootRecord, openVault, rotatedPayload, sealVault } from "./vault.js";
import { prfInput, unwrapWithPhrase, unwrapWithPrf, wrapWithPhrase, wrapWithPrf } from "./wrappers.js";
import { newRecoverySecret, secretToWords, wordsToSecret } from "./recovery-words.js";
import { newPairingKeyPair, openFromPairing, sealForPairing } from "./pairing.js";
import { blindSign, blindToken, finalizeToken, importIssuerPrivateKey, importIssuerPublicKey, verifyToken } from "./blind-token.js";
import type { ControlVaultPayload, EligibilityInfo } from "./contract.js";

// Anonymous Control v2 — the protocol layer both platforms share (spec §42.2
// core invariants 1–5, 13–14, 18–23) plus the known-answer vectors iOS reads.

const M = fromHex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f");
const EPOCH = { schoolId: "huayaopudong", academicYear: "2026-27" };
const NEXT = { schoolId: "huayaopudong", academicYear: "2027-28" };

describe("JCS canonical JSON (RFC 8785)", () => {
  it("sorts members, drops whitespace and undefined, keeps ES number/string forms", () => {
    expect(canonicalize({ b: 1, a: [true, null, "xé\n"], c: undefined, d: { z: 1e21, y: 0.1 } })).toBe(
      '{"a":[true,null,"xé\\n"],"b":1,"d":{"y":0.1,"z":1e+21}}',
    );
    expect(canonicalize({ "é": 1, e: 2, "😀": 3 })).toBe('{"e":2,"é":1,"😀":3}');
    expect(() => canonicalize({ a: Number.POSITIVE_INFINITY })).toThrow();
  });
});

describe("key hierarchy", () => {
  it("same root + school/year → same posting key; different year, school, purpose or root → different keys", () => {
    const a = postingKeyPair(M, EPOCH);
    const b = postingKeyPair(M, EPOCH);
    expect(bytesEqual(a.publicKey, b.publicKey)).toBe(true);
    expect(bytesEqual(postingKeyPair(M, NEXT).publicKey, a.publicKey)).toBe(false);
    expect(bytesEqual(postingKeyPair(M, { ...EPOCH, schoolId: "other" }).publicKey, a.publicKey)).toBe(false);
    expect(bytesEqual(reactionKeyPair(M, EPOCH).publicKey, a.publicKey)).toBe(false);
    expect(bytesEqual(postingKeyPair(randomBytes(32), EPOCH).publicKey, a.publicKey)).toBe(false);
    expect(authorTag(a.publicKey)).toHaveLength(64);
    expect(authorTag(a.publicKey)).not.toBe(authorTag(postingKeyPair(M, NEXT).publicKey));
  });

  it("per-post control keys differ per nonce; a posting key cannot stand in for a control key", () => {
    const n1 = randomBytes(32);
    const n2 = randomBytes(32);
    const c1 = postControlKeyPair(M, n1, EPOCH);
    const c2 = postControlKeyPair(M, n2, EPOCH);
    expect(bytesEqual(c1.publicKey, c2.publicKey)).toBe(false);
    expect(bytesEqual(postControlKeyPair(M, n1, EPOCH).publicKey, c1.publicKey)).toBe(true);
    const statement = { purpose: "honey/v2/revoke", experienceId: "x", challenge: "c", expiresAt: 1 };
    const sig = signStatement(postingKeyPair(M, EPOCH).privateKey, statement);
    expect(verifyStatement(c1.publicKey, statement, sig)).toBe(false);
    expect(verifyStatement(postingKeyPair(M, EPOCH).publicKey, statement, sig)).toBe(true);
    expect(verifyStatement(postingKeyPair(M, EPOCH).publicKey, { ...statement, experienceId: "y" }, sig)).toBe(false);
  });
});

describe("control vault", () => {
  const R = fromHex("ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100");

  it("seals and opens; wrong key, tampered revision or ciphertext fail authentication", async () => {
    const payload = initialPayload(newRootRecord(M, 1000), [EPOCH], 1000);
    const sealed = await sealVault(R, "vault-1", 1, payload);
    const opened = await openVault(R, { vaultId: "vault-1", revision: 1, ...sealed });
    expect(opened).toEqual(payload);
    await expect(openVault(randomBytes(32), { vaultId: "vault-1", revision: 1, ...sealed })).rejects.toThrow();
    await expect(openVault(R, { vaultId: "vault-1", revision: 2, ...sealed })).rejects.toThrow();
    await expect(openVault(R, { vaultId: "vault-2", revision: 1, ...sealed })).rejects.toThrow();
    const bytes = fromBase64Url(sealed.ciphertext);
    bytes[3] = (bytes[3] ?? 0) ^ 1;
    await expect(openVault(R, { vaultId: "vault-1", revision: 1, iv: sealed.iv, ciphertext: toBase64Url(bytes) })).rejects.toThrow();
  });

  it("rotation keeps the old root (legacy) and changes the future posting key; merge unions by id", () => {
    const first = initialPayload(newRootRecord(M, 1000), [EPOCH], 1000);
    const M2 = randomBytes(32);
    const rotated = rotatedPayload(first, M2, 2000);
    expect(rotated.roots).toHaveLength(2);
    expect(rotated.roots.find((r) => r.rootId === first.activeRootId)?.state).toBe("legacy");
    expect(activeRoot(rotated).secret).toBe(toBase64Url(M2));
    expect(bytesEqual(postingKeyPair(fromBase64Url(activeRoot(rotated).secret), EPOCH).publicKey, postingKeyPair(M, EPOCH).publicKey)).toBe(false);

    // Local rotated, remote only added an epoch: union with the rotation winning.
    const remote: ControlVaultPayload = { ...first, schoolEpochs: [EPOCH, NEXT], updatedAt: 1500 };
    const merged = mergePayloads(rotated, remote, 3000);
    expect(merged.activeRootId).toBe(rotated.activeRootId);
    expect(merged.schoolEpochs).toHaveLength(2);
    expect(merged.roots).toHaveLength(2);
    // Both sides rotated to different roots: refuse, never guess.
    const otherRotation = rotatedPayload(first, randomBytes(32), 2500);
    expect(() => mergePayloads(rotated, otherRotation, 3000)).toThrow(/contradictory/);
  });
});

describe("wrappers", () => {
  const R = randomBytes(32);

  it("passkey PRF: the same PRF output unwraps the same R; another output does not", async () => {
    const P = randomBytes(32);
    const w = await wrapWithPrf(P, "vault-1", "cred-1", R, 1000, "Safari on iPhone");
    expect(fromBase64Url(w.prfInput)).toEqual(prfInput("vault-1"));
    expect(bytesEqual(await unwrapWithPrf(P, "vault-1", w), R)).toBe(true);
    await expect(unwrapWithPrf(randomBytes(32), "vault-1", w)).rejects.toThrow();
    await expect(unwrapWithPrf(P, "vault-2", w)).rejects.toThrow();
  });

  it("recovery words: 12 words with a checksum; the right words restore R, a wrong checksum is refused locally", async () => {
    const S = newRecoverySecret();
    const words = secretToWords(S);
    expect(words).toHaveLength(12);
    expect(bytesEqual(wordsToSecret(words.join("  ").toUpperCase())!, S)).toBe(true);
    const wrong = [...words];
    wrong[11] = wrong[11] === "abandon" ? "ability" : "abandon";
    expect(wordsToSecret(wrong)).toBeNull(); // checksum (or wordlist) fails before any network use
    expect(wordsToSecret(words.slice(0, 11))).toBeNull();
    const w = await wrapWithPhrase(S, "vault-1", R, 1000);
    expect(bytesEqual(await unwrapWithPhrase(S, "vault-1", w), R)).toBe(true);
    await expect(unwrapWithPhrase(newRecoverySecret(), "vault-1", w)).rejects.toThrow();
  });

  it("pairing: HPKE to the new device's ephemeral key; bound to the pairing id", async () => {
    const kp = await newPairingKeyPair();
    const { enc, ciphertext } = await sealForPairing(kp.publicKey, "pair-1", R);
    expect(bytesEqual(await openFromPairing(kp.privateKey, "pair-1", enc, ciphertext), R)).toBe(true);
    await expect(openFromPairing(kp.privateKey, "pair-2", enc, ciphertext)).rejects.toThrow();
    const other = await newPairingKeyPair();
    await expect(openFromPairing(other.privateKey, "pair-1", enc, ciphertext)).rejects.toThrow();
  });
});

const TEST_KEY_PATH = fileURLToPath(new URL("./fixtures/issuer-test.jwk.json", import.meta.url));

describe.skipIf(!existsSync(TEST_KEY_PATH))("blind eligibility tokens (RSAPBSSA, public metadata)", () => {
  const info: EligibilityInfo = {
    v: 2,
    schoolId: "huayaopudong",
    academicYear: "2026-27",
    scope: "course:c_abc",
    contexts: { courseId: "c_abc" },
    provenance: "verified_retrospective",
    week: 2956,
  };

  it("issues a token the issuer never saw and Community verifies offline; metadata is bound", async () => {
    const jwk = JSON.parse(readFileSync(TEST_KEY_PATH, "utf8")) as { private: JsonWebKey; public: { kty: "RSA"; n: string; e: string } };
    const priv = await importIssuerPrivateKey(jwk.private);
    const pub = await importIssuerPublicKey(jwk.public);
    const blinded = await blindToken(pub, info);
    // The issuer sees only the blinded message and the public metadata.
    expect(blinded.blindedMessage).toHaveLength(256);
    const blindSig = await blindSign(priv, blinded.blindedMessage, info);
    const token = await finalizeToken(pub, "k1", blinded, info, blindSig);
    expect(await verifyToken(pub, token)).toBe(true);
    // A token issued for course A cannot be redeemed for course B: the
    // metadata is inside the signed message.
    expect(await verifyToken(pub, { ...token, info: { ...info, scope: "course:c_other", contexts: { courseId: "c_other" } } })).toBe(false);
    expect(await verifyToken(pub, { ...token, info: { ...info, academicYear: "2027-28" } })).toBe(false);
    // Nothing in the token repeats the blinded message the issuer saw.
    expect(toBase64Url(blinded.blindedMessage)).not.toContain(token.signature.slice(0, 16));
  }, 30_000);
});

describe("known-answer vectors", () => {
  it("match fixtures/vectors.json (what iOS checks against)", () => {
    const path = fileURLToPath(new URL("./fixtures/vectors.json", import.meta.url));
    if (!existsSync(path)) return; // written by `pnpm --filter @honey/shared vectors:write`
    const v = JSON.parse(readFileSync(path, "utf8")) as {
      root: string;
      epoch: { schoolId: string; academicYear: string };
      schoolSalt: string;
      postingPublicKey: string;
      authorTag: string;
      postNonce: string;
      controlPublicKey: string;
      reactionPublicKey: string;
      statement: Record<string, unknown>;
      statementCanonical: string;
      statementSignature: string;
    };
    const root = fromBase64Url(v.root);
    expect(toBase64Url(schoolSalt(v.epoch))).toBe(v.schoolSalt);
    const posting = postingKeyPair(root, v.epoch);
    expect(toBase64Url(posting.publicKey)).toBe(v.postingPublicKey);
    expect(authorTag(posting.publicKey)).toBe(v.authorTag);
    expect(toBase64Url(postControlKeyPair(root, fromBase64Url(v.postNonce), v.epoch).publicKey)).toBe(v.controlPublicKey);
    expect(toBase64Url(reactionKeyPair(root, v.epoch).publicKey)).toBe(v.reactionPublicKey);
    expect(canonicalize(v.statement as never)).toBe(v.statementCanonical);
    expect(toBase64Url(signStatement(posting.privateKey, v.statement as never))).toBe(v.statementSignature);
    expect(utf8(v.statementCanonical)).toBeInstanceOf(Uint8Array);
  });
});
