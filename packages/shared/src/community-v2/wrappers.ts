// Wrapping the vault root R (spec §35.2, §36, §37): each recovery method
// derives its own AES-256-GCM key and wraps the same 32-byte R, so methods
// can be added or removed one at a time without re-encrypting the vault.
//
//   device key        non-extractable CryptoKey (browser) / Keychain (iOS)
//   passkey PRF       K = HKDF(P, salt = SHA-256(vaultId), info = vault-prf-wrap)
//   recovery phrase   K = HKDF(S_phrase, salt = SHA-256(vaultId), info = vault-phrase-wrap)

import { hkdf } from "@noble/hashes/hkdf.js";
import { sha256 } from "@noble/hashes/sha2.js";
import { concat, fromBase64Url, plain, randomBytes, toBase64Url, utf8 } from "./bytes.js";
import type { PasskeyPrfWrapper, RecoveryPhraseWrapper } from "./contract.js";
import { LABELS, RECOVERY_PHRASE_FORMAT } from "./key-labels.js";

const subtle = () => globalThis.crypto.subtle;

export interface Wrapped {
  iv: string;
  wrappedR: string;
}

async function importAes(raw: Uint8Array, usage: KeyUsage[]): Promise<CryptoKey> {
  return subtle().importKey("raw", plain(raw), { name: "AES-GCM" }, false, usage);
}

export async function wrapWithKey(key: CryptoKey, r: Uint8Array, aad: Uint8Array): Promise<Wrapped> {
  const iv = randomBytes(12);
  const ct = await subtle().encrypt({ name: "AES-GCM", iv: plain(iv), additionalData: plain(aad) }, key, plain(r));
  return { iv: toBase64Url(iv), wrappedR: toBase64Url(new Uint8Array(ct)) };
}

export async function unwrapWithKey(key: CryptoKey, wrapped: Wrapped, aad: Uint8Array): Promise<Uint8Array> {
  const pt = await subtle().decrypt(
    { name: "AES-GCM", iv: plain(fromBase64Url(wrapped.iv)), additionalData: plain(aad) },
    key,
    plain(fromBase64Url(wrapped.wrappedR)),
  );
  return new Uint8Array(pt);
}

export function wrapperAad(vaultId: string, kind: "passkey_prf" | "recovery_phrase" | "device"): Uint8Array {
  return utf8(`honey/v2/wrapper\0${kind}\0${vaultId}`);
}

// ---- passkey PRF ----------------------------------------------------------

/** prfInput = SHA-256("honey/v2/vault-prf-input\0" ‖ vaultId): stable, not reusable elsewhere. */
export function prfInput(vaultId: string): Uint8Array {
  return sha256(concat(utf8(LABELS.vaultPrfInputPrefix), utf8(vaultId)));
}

export function prfWrapKey(prfOutput: Uint8Array, vaultId: string): Uint8Array {
  if (prfOutput.length !== 32) throw new Error("PRF output must be 32 bytes");
  return hkdf(sha256, prfOutput, sha256(utf8(vaultId)), utf8(LABELS.vaultPrfWrap), 32);
}

export async function wrapWithPrf(prfOutput: Uint8Array, vaultId: string, credentialId: string, r: Uint8Array, now: number, label?: string): Promise<PasskeyPrfWrapper> {
  const key = await importAes(prfWrapKey(prfOutput, vaultId), ["encrypt"]);
  const w = await wrapWithKey(key, r, wrapperAad(vaultId, "passkey_prf"));
  const out: PasskeyPrfWrapper = { type: "passkey_prf", credentialId, prfInput: toBase64Url(prfInput(vaultId)), iv: w.iv, wrappedR: w.wrappedR, createdAt: now };
  if (label) out.label = label;
  return out;
}

export async function unwrapWithPrf(prfOutput: Uint8Array, vaultId: string, wrapper: PasskeyPrfWrapper): Promise<Uint8Array> {
  const key = await importAes(prfWrapKey(prfOutput, vaultId), ["decrypt"]);
  return unwrapWithKey(key, wrapper, wrapperAad(vaultId, "passkey_prf"));
}

// ---- recovery phrase ------------------------------------------------------

export function phraseWrapKey(recoverySecret: Uint8Array, vaultId: string): Uint8Array {
  if (recoverySecret.length !== 16) throw new Error("recovery secret must be 16 bytes");
  return hkdf(sha256, recoverySecret, sha256(utf8(vaultId)), utf8(LABELS.vaultPhraseWrap), 32);
}

export async function wrapWithPhrase(recoverySecret: Uint8Array, vaultId: string, r: Uint8Array, now: number): Promise<RecoveryPhraseWrapper> {
  const key = await importAes(phraseWrapKey(recoverySecret, vaultId), ["encrypt"]);
  const w = await wrapWithKey(key, r, wrapperAad(vaultId, "recovery_phrase"));
  return { type: "recovery_phrase", format: RECOVERY_PHRASE_FORMAT, iv: w.iv, wrappedR: w.wrappedR, createdAt: now };
}

export async function unwrapWithPhrase(recoverySecret: Uint8Array, vaultId: string, wrapper: RecoveryPhraseWrapper): Promise<Uint8Array> {
  const key = await importAes(phraseWrapKey(recoverySecret, vaultId), ["decrypt"]);
  return unwrapWithKey(key, wrapper, wrapperAad(vaultId, "recovery_phrase"));
}
