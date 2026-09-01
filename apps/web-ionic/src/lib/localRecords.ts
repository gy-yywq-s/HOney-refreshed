export interface PrivateNote {
  id: string;
  target: string;
  targetLabel: string;
  body: string;
  savedAt: number;
  state?: "private" | "cooldown" | "needs-attention";
}

export interface ComposerDraft {
  target: string;
  targetLabel: string;
  body: string;
  savedAt: number;
}

const NOTE_KEY = "HOney.ionic.private-notes";
const DRAFT_KEY = "HOney.ionic.composer-draft";
const OWNERSHIP_KEY = "HOney.ionic.ownership-keys";

export interface OwnershipRecord { experienceId: string; key: string; }

function read<T>(key: string, fallback: T): T {
  const raw = localStorage.getItem(key);
  if (!raw) return fallback;
  try { return JSON.parse(raw) as T; } catch { return fallback; }
}

export const localRecords = {
  notes(): PrivateNote[] { return read<PrivateNote[]>(NOTE_KEY, []); },
  saveNote(note: PrivateNote): void {
    const notes = this.notes().filter((item) => item.id !== note.id);
    localStorage.setItem(NOTE_KEY, JSON.stringify([note, ...notes]));
  },
  removeNote(id: string): void {
    localStorage.setItem(NOTE_KEY, JSON.stringify(this.notes().filter((item) => item.id !== id)));
  },
  draft(): ComposerDraft | null { return read<ComposerDraft | null>(DRAFT_KEY, null); },
  saveDraft(draft: ComposerDraft): void { localStorage.setItem(DRAFT_KEY, JSON.stringify(draft)); },
  clearDraft(): void { localStorage.removeItem(DRAFT_KEY); },
  ownershipRecords(): OwnershipRecord[] { return read<OwnershipRecord[]>(OWNERSHIP_KEY, []); },
  ownershipKeys(): string[] { return this.ownershipRecords().map((item) => item.key); },
  addOwnershipKey(experienceId: string, key: string): void {
    const records = this.ownershipRecords().filter((item) => item.experienceId !== experienceId);
    localStorage.setItem(OWNERSHIP_KEY, JSON.stringify([{ experienceId, key }, ...records]));
  },
  removeOwnershipKey(experienceId: string): void {
    localStorage.setItem(OWNERSHIP_KEY, JSON.stringify(this.ownershipRecords().filter((item) => item.experienceId !== experienceId)));
  },
};
