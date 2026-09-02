// Seamless School Portal connection on web — the browser plays the role the
// iOS Keychain plays on device (docs/design/web-portal-seamless.md).
//
// Why credentials at all: the OASIS portal issues a 24h token with NO refresh
// token, so surviving expiry REQUIRES a full re-login. iOS achieves "never ask
// again" by holding the school username/password in the Keychain and silently
// re-logging in. The only faithful web analog is a device-local credential
// store here. Storage is opt-in and OFF by default.
//
// Honest threat model (mirrors ownershipKeys.ts): credentials are AES-GCM
// encrypted, but the key sits in the SAME localStorage — a plain web app cannot
// keep a secret from same-origin script without a user passphrase the product
// does not ask for. The encryption buys: no plaintext password in storage
// dumps / disk backups / sync viewers. It does NOT defend against an attacker
// who can already read all of this origin's localStorage (full-profile access
// or XSS). This is a weaker store than the iOS Keychain; the opt-in copy says so.
// The HOney backend still never persists the password — silent reconnect just
// replays it to the same /api/auth/login the manual sign-in uses, transiently.

const CRED_STORAGE_KEY = "honey.portal.cred";
const CRED_CRYPTOKEY_KEY = "honey.portal.credKey";
/** Set only when the student turned "Stay connected" OFF in Settings: the
 *  store is wanted by default (Gary, 2026-09-02 — no choice at sign-in). */
const OPT_OUT_KEY = "honey.portal.stayOff";
const STORE_VERSION = 1;

export interface PortalCredentials {
  username: string;
  password: string;
}

interface CredBlob {
  version: number;
  iv: string;
  data: string;
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

function defaultStorage(): StorageLike {
  if (typeof localStorage === "undefined") {
    const m = new Map<string, string>();
    return {
      getItem: (k) => m.get(k) ?? null,
      setItem: (k, v) => void m.set(k, v),
      removeItem: (k) => void m.delete(k),
    };
  }
  return localStorage;
}

function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function fromBase64(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export class PortalCredentialStore {
  constructor(
    private readonly storage: StorageLike = defaultStorage(),
    private readonly cryptoObj: Crypto = globalThis.crypto,
  ) {}

  /** True while credentials are actually kept on this device. */
  isAuthorized(): boolean {
    return this.storage.getItem(CRED_STORAGE_KEY) !== null;
  }

  /** Whether the student wants HOney to keep the login here: on unless
   *  they turned it off in Settings. Sign-in and reconnects consult this. */
  wanted(): boolean {
    return this.storage.getItem(OPT_OUT_KEY) === null;
  }

  setWanted(on: boolean): void {
    if (on) this.storage.removeItem(OPT_OUT_KEY);
    else this.storage.setItem(OPT_OUT_KEY, "1");
  }

  /** Opt in: encrypt and keep the school credentials on this device. */
  async authorize(creds: PortalCredentials): Promise<void> {
    const key = await this.key();
    const iv = this.cryptoObj.getRandomValues(new Uint8Array(12));
    const data = await this.cryptoObj.subtle.encrypt(
      { name: "AES-GCM", iv },
      key,
      new TextEncoder().encode(JSON.stringify(creds)),
    );
    const blob: CredBlob = { version: STORE_VERSION, iv: toBase64(iv), data: toBase64(new Uint8Array(data)) };
    this.storage.setItem(CRED_STORAGE_KEY, JSON.stringify(blob));
  }

  /** The stored credentials, or null (not opted in / undecryptable). */
  async load(): Promise<PortalCredentials | null> {
    const raw = this.storage.getItem(CRED_STORAGE_KEY);
    if (!raw) return null;
    try {
      const blob = JSON.parse(raw) as CredBlob;
      const key = await this.key();
      const plain = await this.cryptoObj.subtle.decrypt(
        { name: "AES-GCM", iv: fromBase64(blob.iv) },
        key,
        fromBase64(blob.data),
      );
      const creds = JSON.parse(new TextDecoder().decode(plain)) as PortalCredentials;
      return creds.username && creds.password ? creds : null;
    } catch {
      return null;
    }
  }

  /** Opt out: forget the credentials (and the key) on this device. */
  clear(): void {
    this.storage.removeItem(CRED_STORAGE_KEY);
    this.storage.removeItem(CRED_CRYPTOKEY_KEY);
  }

  private async key(): Promise<CryptoKey> {
    let raw = this.storage.getItem(CRED_CRYPTOKEY_KEY);
    if (!raw) {
      const generated = await this.cryptoObj.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, [
        "encrypt",
        "decrypt",
      ]);
      raw = toBase64(new Uint8Array(await this.cryptoObj.subtle.exportKey("raw", generated)));
      this.storage.setItem(CRED_CRYPTOKEY_KEY, raw);
    }
    return this.cryptoObj.subtle.importKey("raw", fromBase64(raw), { name: "AES-GCM" }, false, [
      "encrypt",
      "decrypt",
    ]);
  }
}

export const portalCredentials = new PortalCredentialStore();
