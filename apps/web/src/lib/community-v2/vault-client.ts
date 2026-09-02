// Vault synchronization (spec §40.1–§40.2): fetch, CAS write with one merge
// retry, and the four-way create/unlock/restore decision. Nothing here ever
// creates a second root while a server vault exists.

import {
  activeRoot,
  fromBase64Url,
  initialPayload,
  mergePayloads,
  mergeWrappers,
  newRootRecord,
  openVault,
  randomBytes,
  rotatedPayload,
  sealVault,
  toBase64Url,
  withEpoch,
  type ControlVaultPayload,
  type VaultPutRequest,
  type VaultPutResponse,
  type VaultRecord,
  type VaultWrapper,
} from "@honey/shared/community-v2";
import { api, ApiError } from "../../api/client";
import { localPostControls, type UnlockedRoots } from "./local-store";

export type VaultStatus =
  | { kind: "unsupported" }
  | { kind: "none" } // no local root, no server vault → create
  | { kind: "local_only"; roots: UnlockedRoots } // offer encrypted backup
  | { kind: "restore_needed"; record: VaultRecord } // server vault, no local root
  | { kind: "ready"; roots: UnlockedRoots; record: VaultRecord | null; wrappers: VaultWrapper[] };

async function fetchVault(): Promise<VaultRecord | null> {
  try {
    return await api.vault();
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) return null;
    throw err;
  }
}

function rootsFromPayload(vaultId: string, r: Uint8Array, payload: ControlVaultPayload): UnlockedRoots {
  const active = activeRoot(payload);
  const roots = payload.roots.map((x) => ({ rootId: x.rootId, secret: fromBase64Url(x.secret), state: x.state }));
  return { vaultId, active: fromBase64Url(active.secret), r, roots: [roots.find((x) => x.rootId === active.rootId)!, ...roots.filter((x) => x.rootId !== active.rootId)] };
}

export const vaultClient = {
  /** The decision table of spec §40.1. */
  async status(account: string): Promise<VaultStatus> {
    if (!localPostControls.available()) return { kind: "unsupported" };
    const [local, record] = await Promise.all([localPostControls.unlock(account), fetchVault()]);
    if (local && record) {
      // Both: synchronize — a newer server revision is merged into the local roots.
      const state = await localPostControls.load(account);
      if (state && record.revision > state.revision) {
        const payload = await openVault(local.r, record);
        const roots = rootsFromPayload(record.vaultId, local.r, payload);
        await localPostControls.save(account, roots, { revision: record.revision, wrappers: record.wrappers });
        return { kind: "ready", roots, record, wrappers: record.wrappers };
      }
      return { kind: "ready", roots: local, record, wrappers: record.wrappers };
    }
    if (local && !record) return { kind: "local_only", roots: local };
    if (!local && record) return { kind: "restore_needed", record };
    return { kind: "none" };
  },

  /** Create the initial root M1 and wrapping root R (spec §40.1 no/no); nothing uploads until a wrapper exists. */
  async createInitial(account: string, epoch: { schoolId: string; academicYear: string }): Promise<UnlockedRoots> {
    const record = await fetchVault();
    if (record) throw new Error("a vault already exists: restore it instead of creating a new root");
    const m = randomBytes(32);
    const r = randomBytes(32);
    const now = Date.now();
    const root = newRootRecord(m, now);
    const payload = initialPayload(root, [epoch], now);
    const vaultId = `v_${toBase64Url(randomBytes(16))}`;
    const roots = rootsFromPayload(vaultId, r, payload);
    await localPostControls.save(account, roots, { revision: 0, wrappers: [] });
    return roots;
  },

  /** Current payload from local roots (the vault content is derivable from what the device holds). */
  payloadFor(roots: UnlockedRoots, epochs: { schoolId: string; academicYear: string }[], now = Date.now()): ControlVaultPayload {
    const active = roots.roots.find((x) => x.state === "active")!;
    let payload: ControlVaultPayload = {
      version: 2,
      roots: roots.roots.map((x) => ({ rootId: x.rootId, secret: toBase64Url(x.secret), state: x.state, createdAt: now })),
      activeRootId: active.rootId,
      schoolEpochs: [],
      createdAt: now,
      updatedAt: now,
    };
    for (const e of epochs) payload = withEpoch(payload, e, now);
    return payload;
  },

  /**
   * Upload: seal the payload for the next revision, CAS-put, and on conflict
   * merge the server's newer payload with ours ONCE and retry. Local state is
   * only updated after the server accepted and the readback decrypts.
   */
  async upload(account: string, roots: UnlockedRoots, payload: ControlVaultPayload, wrappers: VaultWrapper[]): Promise<VaultRecord> {
    const state = await localPostControls.load(account);
    let base = state?.revision ?? 0;
    let current = payload;
    let currentWrappers = wrappers;
    for (let attempt = 0; attempt < 2; attempt++) {
      const revision = base + 1;
      const sealed = await sealVault(roots.r, roots.vaultId, revision, current);
      const put: VaultPutRequest = { vaultId: roots.vaultId, baseRevision: base, iv: sealed.iv, ciphertext: sealed.ciphertext, wrappers: currentWrappers };
      const result: VaultPutResponse = await api.vaultPut(put);
      if (result.ok) {
        const record = await fetchVault();
        if (!record || record.revision !== result.revision) throw new Error("vault readback failed");
        // Readback + decrypt-verify before anything reports success (spec §40.3 no.6).
        const verified = await openVault(roots.r, record);
        const merged = rootsFromPayload(record.vaultId, roots.r, verified);
        await localPostControls.save(account, merged, { revision: record.revision, wrappers: record.wrappers });
        return record;
      }
      if (result.current.revision === 0 || result.current.vaultId !== roots.vaultId) {
        throw new Error("vault conflict: a different vault exists for this account");
      }
      const remote = await openVault(roots.r, result.current);
      current = mergePayloads(current, remote, Date.now());
      currentWrappers = mergeWrappers(currentWrappers, result.current.wrappers);
      base = result.current.revision;
    }
    throw new Error("vault conflict: could not merge");
  },

  /** Root rotation (spec §40.3): new active root, old one legacy; the vault write must verify before local publication switches. */
  async rotate(account: string, roots: UnlockedRoots, epochs: { schoolId: string; academicYear: string }[], wrappers: VaultWrapper[]): Promise<UnlockedRoots> {
    const payload = rotatedPayload(this.payloadFor(roots, epochs), randomBytes(32), Date.now());
    const record = await this.upload(account, roots, payload, wrappers);
    const verified = await openVault(roots.r, record);
    return rootsFromPayload(record.vaultId, roots.r, verified);
  },

  /** Restore: with R recovered through a wrapper, decrypt the server vault and keep the roots locally. */
  async restoreWithR(account: string, record: VaultRecord, r: Uint8Array): Promise<UnlockedRoots> {
    const payload = await openVault(r, record);
    const roots = rootsFromPayload(record.vaultId, r, payload);
    await localPostControls.save(account, roots, { revision: record.revision, wrappers: record.wrappers });
    return roots;
  },
};
