import {
  createCipheriv,
  createDecipheriv,
  createHash,
  hkdfSync,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from "node:crypto";

// All primitives from node:crypto (stdlib-first rule).

/** Unambiguous lowercase alphabet (no 0/1/i/l/o) — honeyIds read cleanly aloud. */
const HONEY_ID_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz";

export function generateHoneyId(length = 6): string {
  let id = "";
  for (let i = 0; i < length; i++) id += HONEY_ID_ALPHABET[randomInt(HONEY_ID_ALPHABET.length)];
  return id;
}

/** Opaque bearer token (256-bit, base64url). */
export function generateToken(): string {
  return randomBytes(32).toString("base64url");
}

/** Tokens are stored hashed; a DB leak must not leak live sessions. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

export function tokensEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  return ba.length === bb.length && timingSafeEqual(ba, bb);
}

/**
 * Seal/open small secrets at rest (the portal token) with AES-256-GCM.
 * Layout: 12-byte IV ‖ 16-byte tag ‖ ciphertext.
 */
export function seal(plaintext: string, key: Buffer): Buffer {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), enc]);
}

export function open(sealed: Buffer, key: Buffer): string {
  const iv = sealed.subarray(0, 12);
  const tag = sealed.subarray(12, 28);
  const enc = sealed.subarray(28);
  const decipher = createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]).toString("utf8");
}

/**
 * Domain-separated 32-byte subkey from the master seal key (HKDF-SHA256). One
 * key compromise should not simultaneously break signing, dedup-mark
 * unlinkability, and at-rest encryption — so each purpose gets its own subkey.
 */
export function deriveKey(master: Buffer, label: string): Buffer {
  return Buffer.from(hkdfSync("sha256", master, Buffer.alloc(0), `honey/${label}`, 32));
}
