// Post Controls on the Web: the one object the pages talk to. It owns the
// current unlocked roots for the signed-in account, the school epochs, and
// the recovery methods (passkey PRF · recovery words · pairing). Every
// success it reports is a durable write that was read back and verified.

import {
  newPairingKeyPair,
  newRecoverySecret,
  openFromPairing,
  prfInput,
  sealForPairing,
  secretToWords,
  toBase64Url,
  unwrapWithPhrase,
  unwrapWithPrf,
  wordsToSecret,
  wrapWithPhrase,
  wrapWithPrf,
  type PasskeyPrfWrapper,
  type RecoveryPhraseWrapper,
  type VaultRecord,
  type VaultWrapper,
} from "@honey/shared/community-v2";
import { api, ApiError } from "../../api/client";
import { localPostControls, type UnlockedRoots } from "./local-store";
import { createPasskeyWithPrf, deviceLabel, getPrf } from "./passkey-prf";
import { vaultClient, type VaultStatus } from "./vault-client";

export interface Epoch {
  schoolId: string;
  academicYear: string;
}

async function currentEpoch(): Promise<Epoch> {
  const scope = await api.communityScope();
  return { schoolId: scope.schoolId, academicYear: scope.academicYear };
}

export const postControls = {
  status(account: string): Promise<VaultStatus> {
    return vaultClient.status(account);
  },

  /** Unlocked roots for publishing, or null when this device has none. */
  roots(account: string): Promise<UnlockedRoots | null> {
    return localPostControls.unlock(account);
  },

  /** First-time setup on a device with no root anywhere. */
  async create(account: string): Promise<UnlockedRoots> {
    const epoch = await currentEpoch();
    return vaultClient.createInitial(account, epoch);
  },

  async epochs(account: string, roots: UnlockedRoots): Promise<Epoch[]> {
    const epoch = await currentEpoch();
    const state = await localPostControls.load(account);
    const seen = new Map<string, Epoch>();
    seen.set(`${epoch.schoolId}\0${epoch.academicYear}`, epoch);
    // Epochs recorded in the vault payload cache, when present.
    if (state?.payloadCache) {
      try {
        const { openVault } = await import("@honey/shared/community-v2");
        const payload = await openVault(roots.r, { vaultId: roots.vaultId, ...state.payloadCache });
        for (const e of payload.schoolEpochs) seen.set(`${e.schoolId}\0${e.academicYear}`, e);
      } catch {
        /* cache unreadable: the current epoch is still right */
      }
    }
    return [...seen.values()];
  },

  // ---- recovery words -----------------------------------------------------

  /** Generate words + wrapper; nothing is saved until `commitRecoveryWords` (after the quiz). */
  async prepareRecoveryWords(roots: UnlockedRoots): Promise<{ words: string[]; wrapper: RecoveryPhraseWrapper }> {
    const secret = newRecoverySecret();
    const wrapper = await wrapWithPhrase(secret, roots.vaultId, roots.r, Date.now());
    return { words: secretToWords(secret), wrapper };
  },

  /** After the quiz: upload the vault with the phrase wrapper (replacing an older phrase wrapper). */
  async commitRecoveryWords(account: string, roots: UnlockedRoots, wrapper: RecoveryPhraseWrapper): Promise<VaultRecord> {
    const existing = (await localPostControls.load(account))?.wrappers ?? [];
    const wrappers: VaultWrapper[] = [...existing.filter((w) => w.type !== "recovery_phrase"), wrapper];
    const payload = vaultClient.payloadFor(roots, await this.epochs(account, roots));
    return vaultClient.upload(account, roots, payload, wrappers);
  },

  /** Restore from 12 words: the checksum is checked locally before any unwrap attempt. */
  async restoreWithWords(account: string, record: VaultRecord, words: string): Promise<UnlockedRoots | null> {
    const secret = wordsToSecret(words);
    if (!secret) return null;
    const wrapper = record.wrappers.find((w): w is RecoveryPhraseWrapper => w.type === "recovery_phrase");
    if (!wrapper) return null;
    try {
      const r = await unwrapWithPhrase(secret, record.vaultId, wrapper);
      return await vaultClient.restoreWithR(account, record, r);
    } catch {
      return null;
    }
  },

  // ---- passkey PRF ----------------------------------------------------------

  /** Create a passkey, verify with a fresh assertion that it unwraps R, then upload the wrapper. */
  async addPasskey(account: string, roots: UnlockedRoots, displayName: string): Promise<{ ok: true; record: VaultRecord } | { ok: false; reason: "unsupported" | "cancelled" | "verify_failed" }> {
    const input = prfInput(roots.vaultId);
    const created = await createPasskeyWithPrf(account, displayName, input);
    if (!created) return { ok: false, reason: "unsupported" };
    const wrapper = await wrapWithPrf(created.prfOutput, roots.vaultId, created.credentialId, roots.r, Date.now(), deviceLabel());
    // Readback: a fresh assertion must produce the same output and unwrap R.
    const again = await getPrf(created.credentialId, input);
    if (!again) return { ok: false, reason: "cancelled" };
    try {
      const r = await unwrapWithPrf(again.prfOutput, roots.vaultId, wrapper);
      if (toBase64Url(r) !== toBase64Url(roots.r)) return { ok: false, reason: "verify_failed" };
    } catch {
      return { ok: false, reason: "verify_failed" };
    }
    const existing = (await localPostControls.load(account))?.wrappers ?? [];
    const wrappers: VaultWrapper[] = [...existing.filter((w) => !(w.type === "passkey_prf" && w.credentialId === wrapper.credentialId)), wrapper];
    const payload = vaultClient.payloadFor(roots, await this.epochs(account, roots));
    const record = await vaultClient.upload(account, roots, payload, wrappers);
    return { ok: true, record };
  },

  /** Restore with any passkey wrapper the vault carries; null when none works here. */
  async restoreWithPasskey(account: string, record: VaultRecord): Promise<UnlockedRoots | null> {
    const wrappers = record.wrappers.filter((w): w is PasskeyPrfWrapper => w.type === "passkey_prf");
    if (wrappers.length === 0) return null;
    const input = prfInput(record.vaultId);
    // Let the platform pick among the vault's credentials (discoverable), then match the wrapper.
    const result = await getPrf(null, input);
    if (!result) return null;
    const wrapper = wrappers.find((w) => w.credentialId === result.credentialId) ?? null;
    if (!wrapper) return null;
    try {
      const r = await unwrapWithPrf(result.prfOutput, record.vaultId, wrapper);
      return await vaultClient.restoreWithR(account, record, r);
    } catch {
      return null;
    }
  },

  // ---- pairing --------------------------------------------------------------

  /** New device: announce an ephemeral key, show the code, wait for the signed-in device. */
  async beginPairing(): Promise<{ pairingId: string; expiresAt: number; privateKey: string }> {
    const kp = await newPairingKeyPair();
    const offer = await api.vaultPairingOffer(kp.publicKey);
    return { pairingId: offer.pairingId, expiresAt: offer.expiresAt, privateKey: kp.privateKey };
  },

  /** New device: poll until the ciphertext is there, then restore. */
  async completePairing(account: string, pairingId: string, privateKey: string): Promise<UnlockedRoots | null> {
    const delivery = await api.vaultPairingClaim(pairingId);
    if (!delivery) return null;
    const r = await openFromPairing(privateKey, pairingId, delivery.enc, delivery.ciphertext);
    const record = await api.vault();
    return vaultClient.restoreWithR(account, record, r);
  },

  /** Signed-in device: seal R to the code's key. */
  async approvePairing(roots: UnlockedRoots, pairingId: string): Promise<boolean> {
    let offer;
    try {
      offer = await api.vaultPairingRead(pairingId);
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) return false;
      throw err;
    }
    const sealed = await sealForPairing(offer.recipientPublicKey, offer.pairingId, roots.r);
    await api.vaultPairingDeliver(offer.pairingId, sealed.enc, sealed.ciphertext);
    return true;
  },

  /** Same device, another HOney (Safari → installed app): a one-time link whose secret lives in the fragment. */
  async beginHandoff(roots: UnlockedRoots): Promise<string> {
    const kp = await newPairingKeyPair();
    // The relay binds the ciphertext to the pairing id, so: offer first, then seal and deliver.
    const offer = await api.vaultPairingOffer(kp.publicKey);
    const sealed = await sealForPairing(kp.publicKey, offer.pairingId, roots.r);
    await api.vaultPairingDeliver(offer.pairingId, sealed.enc, sealed.ciphertext);
    return `${location.origin}/settings/post-controls#handoff=${offer.pairingId}.${kp.privateKey}`;
  },

  /** Target side of the hand-off link. */
  async completeHandoff(account: string, fragment: string): Promise<UnlockedRoots | null> {
    const m = /^#?handoff=([A-Z0-9]{8})\.([A-Za-z0-9_-]+)$/.exec(fragment);
    if (!m) return null;
    return this.completePairing(account, m[1]!, m[2]!);
  },

  // ---- advanced ---------------------------------------------------------------

  async rotateRoot(account: string, roots: UnlockedRoots): Promise<UnlockedRoots> {
    const wrappers = (await localPostControls.load(account))?.wrappers ?? [];
    return vaultClient.rotate(account, roots, await this.epochs(account, roots), wrappers);
  },

  async eraseLocal(account: string): Promise<void> {
    await localPostControls.erase(account);
  },
};
