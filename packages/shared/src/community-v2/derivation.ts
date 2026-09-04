// The key hierarchy (spec §30). One client-generated root M; per school/year
// posting identity; per-post control keys; purpose-separated subkeys. Pure
// functions over audited primitives (@noble/hashes HKDF/SHA-256, @noble/curves
// Ed25519) so Web, Node tests and the vectors iOS checks against all agree.

import { ed25519 } from "@noble/curves/ed25519.js";
import { hkdf } from "@noble/hashes/hkdf.js";
import { sha256 } from "@noble/hashes/sha2.js";
import { concat, toHex, utf8 } from "./bytes.js";
import { canonicalBytes, type JsonValue } from "./canonical-json.js";
import { LABELS } from "./key-labels.js";

export interface SchoolEpoch {
  schoolId: string;
  academicYear: string;
}

export interface KeyPair {
  publicKey: Uint8Array;
  privateKey: Uint8Array; // the 32-byte Ed25519 seed
}

/** schoolSalt = SHA-256("honey/v2/school-epoch\0" ‖ schoolId ‖ "\0" ‖ academicYear). */
export function schoolSalt(epoch: SchoolEpoch): Uint8Array {
  return sha256(concat(utf8(LABELS.schoolEpochSaltPrefix), utf8(epoch.schoolId), utf8("\0"), utf8(epoch.academicYear)));
}

function keyPairFromSeed(seed: Uint8Array): KeyPair {
  return { publicKey: ed25519.getPublicKey(seed), privateKey: seed };
}

/** The stable school/year posting identity: same root + epoch → same key. */
export function postingKeyPair(root: Uint8Array, epoch: SchoolEpoch): KeyPair {
  const seed = hkdf(sha256, root, schoolSalt(epoch), utf8(LABELS.postingSigning), 32);
  return keyPairFromSeed(seed);
}

/** Internal Community linkage handle — never public, never joined across years. */
export function authorTag(postingPublicKey: Uint8Array): string {
  return toHex(sha256(concat(utf8(LABELS.authorTagPrefix), postingPublicKey)));
}

/** Per-post control key: root + postNonce (32 bytes) + epoch → independent key. */
export function postControlKeyPair(root: Uint8Array, postNonce: Uint8Array, epoch: SchoolEpoch): KeyPair {
  if (postNonce.length !== 32) throw new Error("postNonce must be 32 bytes");
  const info = concat(utf8(LABELS.postControlPrefix), utf8(epoch.schoolId), utf8("\0"), utf8(epoch.academicYear));
  const seed = hkdf(sha256, root, postNonce, info, 32);
  return keyPairFromSeed(seed);
}

/** Reaction/report identity per school/year — a different purpose, an unlinkable key. */
export function reactionKeyPair(root: Uint8Array, epoch: SchoolEpoch): KeyPair {
  const seed = hkdf(sha256, root, schoolSalt(epoch), utf8(LABELS.reactionSigning), 32);
  return keyPairFromSeed(seed);
}

export function reactorTag(reactionPublicKey: Uint8Array): string {
  return toHex(sha256(concat(utf8(LABELS.reactorTagPrefix), reactionPublicKey)));
}

/** Device-local private-notes key (never uploaded). */
export function privateNotesKey(root: Uint8Array, deviceSalt: Uint8Array): Uint8Array {
  return hkdf(sha256, root, deviceSalt, utf8(LABELS.privateNotesLocal), 32);
}

/** Sign the JCS bytes of a statement. */
export function signStatement(privateKey: Uint8Array, statement: JsonValue): Uint8Array {
  return ed25519.sign(canonicalBytes(statement), privateKey);
}

export function verifyStatement(publicKey: Uint8Array, statement: JsonValue, signature: Uint8Array): boolean {
  try {
    return ed25519.verify(signature, canonicalBytes(statement), publicKey);
  } catch {
    return false;
  }
}

export function sha256Hex(bytes: Uint8Array): string {
  return toHex(sha256(bytes));
}
