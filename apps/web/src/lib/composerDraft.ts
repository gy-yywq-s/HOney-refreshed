// Transient composer drafts (audit §3.4). The draft is written to local storage
// BEFORE any moderation call, so a rejected/failed check — or a reload, or a
// crash — never loses the user's own words. Every non-publish outcome returns
// the user to this exact text; a successful publish clears it.
//
// This is plaintext on purpose: it is the user's own working text on their own
// device, short-lived, and re-shown to that same user. It is not a stored
// private note (those live encrypted in ownershipKeys.ts). One slot is enough —
// only one composer is open at a time — and it is keyed by target so switching
// targets never surfaces stale text.

const DRAFT_KEY = "HOney.experiences.draft";

export interface ComposerDraft {
  /** lesson:<id> or the entity_key — the composer target this text belongs to. */
  targetKey: string;
  body: string;
  rating: number | null;
  updatedAt: number;
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
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

export class ComposerDraftStore {
  constructor(private readonly storage: StorageLike = defaultStorage()) {}

  /** The saved draft for this target, or null (a different target's draft is ignored). */
  get(targetKey: string): ComposerDraft | null {
    const raw = this.storage.getItem(DRAFT_KEY);
    if (!raw) return null;
    try {
      const draft = JSON.parse(raw) as ComposerDraft;
      return draft.targetKey === targetKey && typeof draft.body === "string" ? draft : null;
    } catch {
      return null;
    }
  }

  save(draft: Omit<ComposerDraft, "updatedAt">): void {
    this.storage.setItem(DRAFT_KEY, JSON.stringify({ ...draft, updatedAt: Date.now() }));
  }

  /** Clear the slot, but only if it still holds this target's draft. */
  clear(targetKey: string): void {
    if (this.get(targetKey)) this.storage.removeItem(DRAFT_KEY);
  }
}

export const composerDrafts = new ComposerDraftStore();
