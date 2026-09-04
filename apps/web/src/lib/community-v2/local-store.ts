// Device storage for Post Controls on the Web (spec §39.1). The root M and
// the wrapping root R are kept in IndexedDB encrypted under a NON-EXTRACTABLE
// device CryptoKey (the key object itself lives in IndexedDB — structured
// clone keeps it non-extractable). Honest limit: same-origin script can still
// call the crypto while the vault is unlocked; non-extractability only stops
// raw secret export. It is not XSS immunity, and the product copy says so.

import { fromBase64Url, plain, randomBytes, toBase64Url, utf8, fromUtf8 } from "@honey/shared/community-v2";
import type { VaultWrapper } from "@honey/shared/community-v2";

const DB_NAME = "honey.post-controls";
const DB_VERSION = 1;
const STORE = "kv";

export interface LocalRootState {
  vaultId: string;
  /** base64url of M (active root) and R, sealed under the device key. */
  sealed: { iv: string; data: string };
  /** The last vault revision this device merged. */
  revision: number;
  /** Cached wrapper metadata (no secrets) for the Settings list. */
  wrappers: VaultWrapper[];
  /** Vault payload cache (ciphertext) so an offline device still knows its roots. */
  payloadCache?: { iv: string; ciphertext: string; revision: number } | undefined;
  updatedAt: number;
}

export interface UnlockedRoots {
  vaultId: string;
  active: Uint8Array; // M (active)
  r: Uint8Array;
  /** Every root, active first, for listing/revoking old posts. */
  roots: { rootId: string; secret: Uint8Array; state: "active" | "legacy" }[];
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE)) req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error ?? new Error("indexeddb"));
  });
}

async function kvGet<T>(key: string): Promise<T | undefined> {
  const db = await openDb();
  try {
    return await new Promise<T | undefined>((resolve, reject) => {
      const tx = db.transaction(STORE, "readonly");
      const req = tx.objectStore(STORE).get(key);
      req.onsuccess = () => resolve(req.result as T | undefined);
      req.onerror = () => reject(req.error ?? new Error("indexeddb"));
    });
  } finally {
    db.close();
  }
}

async function kvSet(key: string, value: unknown): Promise<void> {
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).put(value, key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error ?? new Error("indexeddb"));
    });
  } finally {
    db.close();
  }
}

async function kvDelete(key: string): Promise<void> {
  const db = await openDb();
  try {
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE, "readwrite");
      tx.objectStore(STORE).delete(key);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error ?? new Error("indexeddb"));
    });
  } finally {
    db.close();
  }
}

/** Storage is per HOney account, so two students on one browser never share roots. */
function stateKey(account: string): string {
  return `state:${account}`;
}

async function deviceKey(): Promise<CryptoKey> {
  const existing = await kvGet<CryptoKey>("device-key");
  if (existing) return existing;
  const key = await crypto.subtle.generateKey({ name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]);
  await kvSet("device-key", key);
  return key;
}

export const localPostControls = {
  available(): boolean {
    return typeof indexedDB !== "undefined" && typeof crypto !== "undefined" && !!crypto.subtle;
  },

  async load(account: string): Promise<LocalRootState | null> {
    try {
      return (await kvGet<LocalRootState>(stateKey(account))) ?? null;
    } catch {
      return null;
    }
  },

  /** Seal M ‖ R ‖ every root under the device key, write, then read back and verify (spec §27 no.27). */
  async save(account: string, roots: UnlockedRoots, meta: { revision: number; wrappers: VaultWrapper[]; payloadCache?: LocalRootState["payloadCache"] }): Promise<LocalRootState> {
    const key = await deviceKey();
    const iv = randomBytes(12);
    const plaintext = utf8(
      JSON.stringify({
        r: toBase64Url(roots.r),
        roots: roots.roots.map((x) => ({ rootId: x.rootId, secret: toBase64Url(x.secret), state: x.state })),
      }),
    );
    const data = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: plain(iv), additionalData: plain(utf8(roots.vaultId)) }, key, plain(plaintext)));
    const state: LocalRootState = {
      vaultId: roots.vaultId,
      sealed: { iv: toBase64Url(iv), data: toBase64Url(data) },
      revision: meta.revision,
      wrappers: meta.wrappers,
      payloadCache: meta.payloadCache,
      updatedAt: Date.now(),
    };
    await kvSet(stateKey(account), state);
    const back = await this.unlock(account);
    if (!back || back.vaultId !== roots.vaultId || toBase64Url(back.r) !== toBase64Url(roots.r)) {
      throw new Error("post controls could not be verified on this device");
    }
    return state;
  },

  /** Open the sealed roots with the device key (no user interaction). */
  async unlock(account: string): Promise<UnlockedRoots | null> {
    const state = await this.load(account);
    if (!state) return null;
    try {
      const key = await deviceKey();
      const pt = await crypto.subtle.decrypt(
        { name: "AES-GCM", iv: plain(fromBase64Url(state.sealed.iv)), additionalData: plain(utf8(state.vaultId)) },
        key,
        plain(fromBase64Url(state.sealed.data)),
      );
      const parsed = JSON.parse(fromUtf8(new Uint8Array(pt))) as { r: string; roots: { rootId: string; secret: string; state: "active" | "legacy" }[] };
      const roots = parsed.roots.map((x) => ({ rootId: x.rootId, secret: fromBase64Url(x.secret), state: x.state }));
      const active = roots.find((x) => x.state === "active");
      if (!active) return null;
      return { vaultId: state.vaultId, active: active.secret, r: fromBase64Url(parsed.r), roots: [active, ...roots.filter((x) => x !== active)] };
    } catch {
      return null;
    }
  },

  async updateMeta(account: string, meta: Partial<Pick<LocalRootState, "revision" | "wrappers" | "payloadCache">>): Promise<void> {
    const state = await this.load(account);
    if (!state) return;
    await kvSet(stateKey(account), { ...state, ...meta, updatedAt: Date.now() });
  },

  /** "Erase local post controls": the sealed roots go; the server vault stays. */
  async erase(account: string): Promise<void> {
    await kvDelete(stateKey(account));
  },
};
