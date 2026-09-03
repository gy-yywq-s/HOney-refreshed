// Blind eligibility tokens (spec §31): RSA partially-blind signatures
// (RSAPBSSA-SHA384-PSS-Randomized, the CFRG partially-blind RSA scheme as
// implemented by @cloudflare/blindrsa-ts). The scope and canonical context
// are PUBLIC METADATA (`info`, the JCS bytes of EligibilityInfo): bound into
// the signature, visible to issuer and verifier, never a per-account value.
// The token message itself is blind to the issuer.

import { RSAPBSSA, type PartiallyBlindRSA } from "@cloudflare/blindrsa-ts";
import { sha256 } from "@noble/hashes/sha2.js";
import { fromBase64Url, plain, randomBytes, toBase64Url } from "./bytes.js";
import { canonicalBytes } from "./canonical-json.js";
import type { EligibilityInfo, EligibilityToken } from "./contract.js";
import { ELIGIBILITY_SUITE } from "./key-labels.js";

function suite(): PartiallyBlindRSA {
  return RSAPBSSA.SHA384.PSS.Randomized();
}

export const suiteName = ELIGIBILITY_SUITE;

export function infoBytes(info: EligibilityInfo): Uint8Array {
  return canonicalBytes(info as never);
}

const subtle = () => globalThis.crypto.subtle;

export async function importIssuerPublicKey(jwk: { kty: "RSA"; n: string; e: string }): Promise<CryptoKey> {
  return subtle().importKey("jwk", { kty: "RSA", n: jwk.n, e: jwk.e, alg: "PS384", ext: true }, { name: "RSA-PSS", hash: "SHA-384" }, true, ["verify"]);
}

export async function importIssuerPrivateKey(jwk: JsonWebKey): Promise<CryptoKey> {
  return subtle().importKey("jwk", { ...jwk, alg: "PS384", ext: true }, { name: "RSA-PSS", hash: "SHA-384" }, true, ["sign"]);
}

export interface BlindedToken {
  /** The prepared message (random prefix ‖ nonce), kept by the client for finalize. */
  message: Uint8Array;
  blindedMessage: Uint8Array;
  inverse: Uint8Array;
}

/** Client, step 1: pick a nonce, prepare, blind under the issuer key + expected info. */
export async function blindToken(issuerPublicKey: CryptoKey, info: EligibilityInfo): Promise<BlindedToken> {
  const s = suite();
  const message = s.prepare(randomBytes(32));
  const { blindedMsg, inv } = await s.blind(issuerPublicKey, plain(message), plain(infoBytes(info)));
  return { message, blindedMessage: blindedMsg, inverse: inv };
}

/** Issuer: sign the blinded message with the metadata it verified. */
export async function blindSign(issuerPrivateKey: CryptoKey, blindedMessage: Uint8Array, info: EligibilityInfo): Promise<Uint8Array> {
  return suite().blindSign(issuerPrivateKey, plain(blindedMessage), plain(infoBytes(info)));
}

function bytesToBigInt(bytes: Uint8Array): bigint {
  let n = 0n;
  for (const b of bytes) n = (n << 8n) | BigInt(b);
  return n;
}

function bigIntToBytes(n: bigint, length: number): Uint8Array {
  const out = new Uint8Array(length);
  let v = n;
  for (let i = length - 1; i >= 0; i--) {
    out[i] = Number(v & 0xffn);
    v >>= 8n;
  }
  if (v !== 0n) throw new Error("integer too large");
  return out;
}

/**
 * Client, step 2: unblind. sig = blindSig · r⁻¹ mod n — one modular
 * multiplication (the protocol's finalize step, RFC 9474 §5.1.4 step 3), done
 * with the platform's native big integers. The library's own finalize verifies
 * the result by importing the DERIVED public key (n, e′) into WebCrypto, and
 * browsers built on BoringSSL refuse the large derived exponent — so the
 * client does not verify here; Community verifies every token offline
 * (Node/OpenSSL accepts e′), and an unusable token is refused there.
 */
export async function finalizeToken(issuerPublicKey: CryptoKey, keyId: string, blinded: BlindedToken, info: EligibilityInfo, blindSignature: Uint8Array): Promise<EligibilityToken> {
  const jwk = (await subtle().exportKey("jwk", issuerPublicKey)) as { n?: string };
  if (!jwk.n) throw new Error("issuer key has no modulus");
  const n = bytesToBigInt(fromBase64Url(jwk.n));
  const kLen = fromBase64Url(jwk.n).length;
  if (blindSignature.length !== kLen || blinded.inverse.length !== kLen) throw new Error("unexpected input size");
  const s = (bytesToBigInt(blindSignature) * bytesToBigInt(blinded.inverse)) % n;
  return { keyId, info, message: toBase64Url(blinded.message), signature: toBase64Url(bigIntToBytes(s, kLen)) };
}

/** Verifier (Community): offline, with the issuer public key only. */
export async function verifyToken(issuerPublicKey: CryptoKey, token: EligibilityToken): Promise<boolean> {
  try {
    return await suite().verify(issuerPublicKey, plain(fromBase64Url(token.signature)), plain(fromBase64Url(token.message)), plain(infoBytes(token.info)));
  } catch {
    return false;
  }
}

/** The single-use handle Community reserves and consumes: SHA-256 of the signature. */
export function tokenHash(token: EligibilityToken): string {
  return toBase64Url(sha256(fromBase64Url(token.signature)));
}
