// Device pairing (spec §38): the new device makes an ephemeral X25519 key
// pair; the signed-in device HPKE-seals R to it (RFC 9180 base mode,
// DHKEM(X25519) · HKDF-SHA256 · AES-256-GCM); the relay holds only the
// ciphertext for minutes. Same-device hand-off is the same envelope with the
// private half carried in a URL fragment the server never sees.

import { Aes256Gcm, CipherSuite, DhkemX25519HkdfSha256, HkdfSha256 } from "@hpke/core";
import { fromBase64Url, plain, toBase64Url, utf8 } from "./bytes.js";
import { LABELS } from "./key-labels.js";

const suite = () => new CipherSuite({ kem: new DhkemX25519HkdfSha256(), kdf: new HkdfSha256(), aead: new Aes256Gcm() });

export interface PairingKeyPair {
  publicKey: string; // base64url raw 32 bytes
  privateKey: string; // base64url raw 32 bytes
}

export async function newPairingKeyPair(): Promise<PairingKeyPair> {
  const s = suite();
  const kp = await s.kem.generateKeyPair();
  return {
    publicKey: toBase64Url(new Uint8Array(await s.kem.serializePublicKey(kp.publicKey))),
    privateKey: toBase64Url(new Uint8Array(await s.kem.serializePrivateKey(kp.privateKey))),
  };
}

function pairingAad(pairingId: string): Uint8Array {
  return utf8(`${LABELS.pairingInfo}\0${pairingId}`);
}

export async function sealForPairing(recipientPublicKey: string, pairingId: string, r: Uint8Array): Promise<{ enc: string; ciphertext: string }> {
  const s = suite();
  const pk = await s.kem.deserializePublicKey(plain(fromBase64Url(recipientPublicKey)).buffer);
  const sender = await s.createSenderContext({ recipientPublicKey: pk, info: plain(utf8(LABELS.pairingInfo)).buffer });
  const ct = await sender.seal(plain(r).buffer, plain(pairingAad(pairingId)).buffer);
  return { enc: toBase64Url(new Uint8Array(sender.enc)), ciphertext: toBase64Url(new Uint8Array(ct)) };
}

export async function openFromPairing(privateKey: string, pairingId: string, enc: string, ciphertext: string): Promise<Uint8Array> {
  const s = suite();
  const sk = await s.kem.deserializePrivateKey(plain(fromBase64Url(privateKey)).buffer);
  const recipient = await s.createRecipientContext({ recipientKey: sk, enc: plain(fromBase64Url(enc)).buffer, info: plain(utf8(LABELS.pairingInfo)).buffer });
  const pt = await recipient.open(plain(fromBase64Url(ciphertext)).buffer, plain(pairingAad(pairingId)).buffer);
  return new Uint8Array(pt);
}
