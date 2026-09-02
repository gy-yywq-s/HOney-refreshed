import type { DatabaseSync } from "node:sqlite";

// Core-side operational settings: the kill switches that gate ISSUANCE, the
// frozen-entity marks used by target resolution, and standalone-review
// modes. Moderation configuration lives in the Community process (its Dash
// panel is proxied there).

export type KillSwitch = "DISABLE_NEW_PUBLICATIONS" | "PRIVATE_NOTES_ONLY_MODE";

export type StandaloneMode = "verified" | "open" | "invite" | "closed";

export class SettingsService {
  constructor(private readonly db: DatabaseSync) {}

  get(key: string): string | null {
    const row = this.db.prepare("SELECT value FROM settings WHERE key = ?").get(key) as unknown as { value: string } | undefined;
    return row?.value ?? null;
  }

  set(key: string, value: string): void {
    this.db.prepare("INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value").run(key, value);
  }

  killSwitch(name: KillSwitch): boolean {
    return this.get(`kill.${name}`) === "1";
  }
  setKillSwitch(name: KillSwitch, on: boolean): void {
    this.set(`kill.${name}`, on ? "1" : "0");
  }
  frozenEntity(entityKey: string): boolean {
    return this.get(`freeze.${entityKey}`) === "1";
  }
  setFrozenEntity(entityKey: string, frozen: boolean): void {
    this.set(`freeze.${entityKey}`, frozen ? "1" : "0");
  }

  /** Per entity type; a per-entity override wins over the type default. */
  standaloneMode(entityKey: string, type: string): StandaloneMode {
    const specific = this.get(`standalone.${entityKey}`);
    if (specific) return specific as StandaloneMode;
    const byType = this.get(`standalone.type.${type}`);
    return (byType as StandaloneMode) ?? "verified";
  }
  setStandaloneMode(scope: string, mode: StandaloneMode): void {
    this.set(`standalone.${scope}`, mode);
  }
}
