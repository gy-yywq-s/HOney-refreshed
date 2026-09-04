// The encrypted Control Vault (spec §35). The payload — every root the
// student has ever used, which one is active, the school epochs seen — is
// AES-256-GCM encrypted under the random wrapping root R with the vault id,
// revision and version authenticated as AAD. The server stores ciphertext it
// cannot read; wrappers (device key, passkey PRF, recovery words) only wrap R.

import { canonicalBytes, canonicalize } from "./canonical-json.js";
import { fromBase64Url, fromUtf8, plain, randomBytes, toBase64Url } from "./bytes.js";
import type { ControlRootRecord, ControlVaultPayload, VaultRecord, VaultWrapper } from "./contract.js";
import { VAULT_VERSION } from "./key-labels.js";

const subtle = () => globalThis.crypto.subtle;

async function aesKey(raw: Uint8Array, usage: KeyUsage[]): Promise<CryptoKey> {
  if (raw.length !== 32) throw new Error("AES-256 key must be 32 bytes");
  return subtle().importKey("raw", plain(raw), { name: "AES-GCM" }, false, usage);
}

export function vaultAad(vaultId: string, revision: number): Uint8Array {
  return canonicalBytes({ revision, vaultId, version: VAULT_VERSION });
}

export interface SealedVault {
  iv: string;
  ciphertext: string;
}

/** Encrypt a payload for revision `revision` under R with a fresh IV. */
export async function sealVault(r: Uint8Array, vaultId: string, revision: number, payload: ControlVaultPayload): Promise<SealedVault> {
  const key = await aesKey(r, ["encrypt"]);
  const iv = randomBytes(12);
  const ct = await subtle().encrypt(
    { name: "AES-GCM", iv: plain(iv), additionalData: plain(vaultAad(vaultId, revision)) },
    key,
    plain(canonicalBytes(payload as never)),
  );
  return { iv: toBase64Url(iv), ciphertext: toBase64Url(new Uint8Array(ct)) };
}

/** Decrypt + authenticate; throws on the wrong key, IV, AAD or a tampered revision. */
export async function openVault(r: Uint8Array, record: Pick<VaultRecord, "vaultId" | "revision" | "iv" | "ciphertext">): Promise<ControlVaultPayload> {
  const key = await aesKey(r, ["decrypt"]);
  const pt = await subtle().decrypt(
    { name: "AES-GCM", iv: plain(fromBase64Url(record.iv)), additionalData: plain(vaultAad(record.vaultId, record.revision)) },
    key,
    plain(fromBase64Url(record.ciphertext)),
  );
  const parsed = JSON.parse(fromUtf8(new Uint8Array(pt))) as ControlVaultPayload;
  if (parsed.version !== VAULT_VERSION || !Array.isArray(parsed.roots) || typeof parsed.activeRootId !== "string") {
    throw new Error("vault payload invalid");
  }
  return parsed;
}

export function newRootRecord(secret: Uint8Array, now: number): ControlRootRecord {
  return { rootId: toBase64Url(randomBytes(12)), secret: toBase64Url(secret), state: "active", createdAt: now };
}

export function initialPayload(root: ControlRootRecord, epochs: ControlVaultPayload["schoolEpochs"], now: number): ControlVaultPayload {
  return { version: VAULT_VERSION, roots: [root], activeRootId: root.rootId, schoolEpochs: epochs, createdAt: now, updatedAt: now };
}

export function activeRoot(payload: ControlVaultPayload): ControlRootRecord {
  const r = payload.roots.find((x) => x.rootId === payload.activeRootId);
  if (!r || r.state !== "active") throw new Error("vault has no active root");
  return r;
}

/**
 * Root rotation (spec §40.3): the current active root becomes legacy, the new
 * one is the sole active root. Old posts stay controllable through the
 * retained root; nothing is re-signed.
 */
export function rotatedPayload(payload: ControlVaultPayload, newSecret: Uint8Array, now: number): ControlVaultPayload {
  const fresh = newRootRecord(newSecret, now);
  const roots: ControlRootRecord[] = payload.roots.map((r) =>
    r.rootId === payload.activeRootId ? { ...r, state: "legacy", retiredAt: now } : r,
  );
  return { ...payload, roots: [...roots, fresh], activeRootId: fresh.rootId, updatedAt: now };
}

export function withEpoch(payload: ControlVaultPayload, epoch: { schoolId: string; academicYear: string }, now: number): ControlVaultPayload {
  if (payload.schoolEpochs.some((e) => e.schoolId === epoch.schoolId && e.academicYear === epoch.academicYear)) return payload;
  return { ...payload, schoolEpochs: [...payload.schoolEpochs, epoch], updatedAt: now };
}

/**
 * Conflict merge (spec §40.2): union roots, epochs and wrappers by stable id;
 * a contradictory active root (both sides rotated to different roots) is
 * rejected rather than guessed.
 */
export function mergePayloads(local: ControlVaultPayload, remote: ControlVaultPayload, now: number): ControlVaultPayload {
  const roots = new Map<string, ControlRootRecord>();
  for (const r of [...remote.roots, ...local.roots]) {
    const prev = roots.get(r.rootId);
    // legacy wins over active for the same root (a retirement is never undone)
    roots.set(r.rootId, prev && prev.state === "legacy" ? prev : r);
  }
  const localActive = local.activeRootId;
  const remoteActive = remote.activeRootId;
  let activeRootId = localActive;
  if (localActive !== remoteActive) {
    const localRetiredRemote = roots.get(remoteActive)?.state === "legacy" && local.roots.some((r) => r.rootId === remoteActive);
    const remoteRetiredLocal = roots.get(localActive)?.state === "legacy" && remote.roots.some((r) => r.rootId === localActive);
    if (localRetiredRemote && !remoteRetiredLocal) activeRootId = localActive;
    else if (remoteRetiredLocal && !localRetiredRemote) activeRootId = remoteActive;
    else throw new Error("vault conflict: contradictory active roots");
  }
  const active = roots.get(activeRootId);
  if (!active) throw new Error("vault conflict: active root missing");
  roots.set(activeRootId, { ...active, state: "active" });
  const epochs = new Map<string, { schoolId: string; academicYear: string }>();
  for (const e of [...remote.schoolEpochs, ...local.schoolEpochs]) epochs.set(`${e.schoolId}\0${e.academicYear}`, e);
  return {
    version: VAULT_VERSION,
    roots: [...roots.values()],
    activeRootId,
    schoolEpochs: [...epochs.values()],
    createdAt: Math.min(local.createdAt, remote.createdAt),
    updatedAt: now,
  };
}

export function mergeWrappers(local: VaultWrapper[], remote: VaultWrapper[]): VaultWrapper[] {
  const byId = new Map<string, VaultWrapper>();
  const idOf = (w: VaultWrapper) => (w.type === "passkey_prf" ? `prf:${w.credentialId}` : `phrase:${w.wrappedR}`);
  for (const w of [...remote, ...local]) byId.set(idOf(w), w);
  return [...byId.values()];
}

export function payloadFingerprint(payload: ControlVaultPayload): string {
  return canonicalize(payload as never);
}
