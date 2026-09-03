// HPKE sealing for the Access capability's portal session (spec §17): Core
// seals to the Access Service's X25519 public key with a label of its own —
// the same primitive wrapper Community pairing uses, never the same keys,
// audience or info string.

import { Aes256Gcm, CipherSuite, DhkemX25519HkdfSha256, HkdfSha256 } from "@hpke/core";
import { fromBase64Url, plain, toBase64Url, utf8 } from "../community-v2/bytes.js";

const INFO = "honey/access/portal-session";
const suite = () => new CipherSuite({ kem: new DhkemX25519HkdfSha256(), kdf: new HkdfSha256(), aead: new Aes256Gcm() });

export interface SealingKeyPair {
  publicKey: string;
  privateKey: string;
}

export async function newSealingKeyPair(): Promise<SealingKeyPair> {
  const s = suite();
  const kp = await s.kem.generateKeyPair();
  return {
    publicKey: toBase64Url(new Uint8Array(await s.kem.serializePublicKey(kp.publicKey))),
    privateKey: toBase64Url(new Uint8Array(await s.kem.serializePrivateKey(kp.privateKey))),
  };
}

/** Seal bytes to a recipient; `aad` binds the ciphertext to its capability id. */
export async function sealTo(recipientPublicKey: string, aad: string, plaintext: Uint8Array): Promise<{ enc: string; ciphertext: string }> {
  const s = suite();
  const pk = await s.kem.deserializePublicKey(plain(fromBase64Url(recipientPublicKey)).buffer);
  const sender = await s.createSenderContext({ recipientPublicKey: pk, info: plain(utf8(INFO)).buffer });
  const ct = await sender.seal(plain(plaintext).buffer, plain(utf8(aad)).buffer);
  return { enc: toBase64Url(new Uint8Array(sender.enc)), ciphertext: toBase64Url(new Uint8Array(ct)) };
}

export async function openSealed(privateKey: string, aad: string, enc: string, ciphertext: string): Promise<Uint8Array> {
  const s = suite();
  const sk = await s.kem.deserializePrivateKey(plain(fromBase64Url(privateKey)).buffer);
  const recipient = await s.createRecipientContext({ recipientKey: sk, enc: plain(fromBase64Url(enc)).buffer, info: plain(utf8(INFO)).buffer });
  return new Uint8Array(await recipient.open(plain(fromBase64Url(ciphertext)).buffer, plain(utf8(aad)).buffer));
}
