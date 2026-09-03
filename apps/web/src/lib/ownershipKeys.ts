// Private notes — spec §7.4 (first-class private note) + §25.1 ("web may use
// device/browser local encrypted storage where practical"). Notes never leave
// the browser and are encrypted at rest with AES-GCM.
//
// (Control of PUBLIC posts no longer lives here: Anonymous Control v2 derives
// per-post control keys from one root kept in lib/community-v2/local-store.)
//
// Honest threat model: private notes are AES-GCM encrypted, but the random
// 256-bit key is stored in the SAME localStorage (a plain web app cannot keep
// a secret from same-origin code without a user passphrase, which the product
// does not ask for). What the encryption buys: note text does not appear in
// plaintext in storage dumps, disk backups, or naive string-scraping of the
// browser profile; casual inspection shows ciphertext, not a student's
// unpublished thoughts. It does NOT defend against an attacker who can read
// all of localStorage.

const NOTES_STORAGE_KEY = "HOney.experiences.notes";
const NOTES_CRYPTOKEY_KEY = "HOney.experiences.notesKey";
const STORE_VERSION = 1;

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface PrivateNoteTarget {
  /** Human-readable summary shown on the card ("Ms Lin — Maths, 12 Mar"). */
  label: string;
  lessonId?: string;
  entityKey?: string;
  /** Set when the target is a dish, so a later publish can offer stars. */
  entityType?: string;
}

export interface NoteCooldown {
  /** When the check may run again (ms epoch). */
  until: number;
  /** The server's stateless cooldown ticket for this exact text. */
  ticket: string;
}

export interface PrivateNote {
  id: string;
  body: string;
  rating: number | null;
  target: PrivateNoteTarget;
  /** Set when the pre-publish check put this text into a cooling-off period. */
  cooldown?: NoteCooldown | null;
  createdAt: number;
  updatedAt: number;
}

function memoryStorage(): StorageLike {
  const map = new Map<string, string>();
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
  };
}

function defaultStorage(): StorageLike {
  return typeof localStorage === "undefined" ? memoryStorage() : localStorage;
}

function toBase64(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

function fromBase64(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

interface NotesBlob {
  version: number;
  /** base64 12-byte IV, fresh per write. */
  iv: string;
  /** base64 AES-GCM ciphertext of the JSON-encoded PrivateNote[]. */
  data: string;
}

export class PrivateNoteStore {
  constructor(
    private readonly storage: StorageLike = defaultStorage(),
    private readonly cryptoObj: Crypto = globalThis.crypto,
  ) {}

  async list(): Promise<PrivateNote[]> {
    const raw = this.storage.getItem(NOTES_STORAGE_KEY);
    if (!raw) return [];
    try {
      const blob = JSON.parse(raw) as NotesBlob;
      if (blob.version !== STORE_VERSION) return [];
      const key = await this.key();
      const plain = await this.cryptoObj.subtle.decrypt({ name: "AES-GCM", iv: fromBase64(blob.iv) }, key, fromBase64(blob.data));
      const notes = JSON.parse(new TextDecoder().decode(plain)) as PrivateNote[];
      return Array.isArray(notes) ? notes : [];
    } catch {
      // Undecryptable (corrupt blob or lost key) — nothing recoverable.
      return [];
    }
  }

  async get(id: string): Promise<PrivateNote | null> {
    return (await this.list()).find((n) => n.id === id) ?? null;
  }

  /** Create (no id) or update (existing id) a note. */
  async save(input: {
    id?: string;
    body: string;
    rating?: number | null;
    target: PrivateNoteTarget;
    /** Omit to keep an existing cooling state; null clears it. */
    cooldown?: NoteCooldown | null;
  }): Promise<PrivateNote> {
    const notes = await this.list();
    const now = Date.now();
    const existing = input.id ? notes.find((n) => n.id === input.id) : undefined;
    const note: PrivateNote = {
      id: existing?.id ?? this.cryptoObj.randomUUID(),
      body: input.body,
      rating: input.rating ?? null,
      target: input.target,
      cooldown: input.cooldown === undefined ? (existing?.cooldown ?? null) : input.cooldown,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };
    const next = existing ? notes.map((n) => (n.id === note.id ? note : n)) : [...notes, note];
    await this.write(next);
    return note;
  }

  async remove(id: string): Promise<void> {
    await this.write((await this.list()).filter((n) => n.id !== id));
  }

  private async write(notes: PrivateNote[]): Promise<void> {
    const key = await this.key();
    const iv = this.cryptoObj.getRandomValues(new Uint8Array(12));
    const data = await this.cryptoObj.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(JSON.stringify(notes)));
    const blob: NotesBlob = { version: STORE_VERSION, iv: toBase64(iv), data: toBase64(new Uint8Array(data)) };
    this.storage.setItem(NOTES_STORAGE_KEY, JSON.stringify(blob));
  }

  /** Load-or-create the device note key (see threat model at top of file). */
  private async key(): Promise<CryptoKey> {
    let raw = this.storage.getItem(NOTES_CRYPTOKEY_KEY);
    if (!raw) {
      const generated = await this.cryptoObj.subtle.generateKey({ name: "AES-GCM", length: 256 }, true, ["encrypt", "decrypt"]);
      const exported = await this.cryptoObj.subtle.exportKey("raw", generated);
      raw = toBase64(new Uint8Array(exported));
      this.storage.setItem(NOTES_CRYPTOKEY_KEY, raw);
    }
    return this.cryptoObj.subtle.importKey("raw", fromBase64(raw), { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
  }
}

/** App-wide singleton (localStorage-backed in the browser). */
export const privateNotes = new PrivateNoteStore();
