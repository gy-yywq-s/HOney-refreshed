import type { DatabaseSync } from "node:sqlite";

// Core-side operational settings: the kill switches that gate ISSUANCE, the
// frozen-entity marks used by target resolution, and standalone-review
// modes. Moderation configuration lives in the Community process (its Dash
// panel is proxied there).

export type KillSwitch = "DISABLE_NEW_PUBLICATIONS" | "PRIVATE_NOTES_ONLY_MODE";

export type StandaloneMode = "verified" | "open" | "invite" | "closed";

export type FeatureName = "lessonFeedback" | "schoolFeedback";

const FEATURE_DEFAULTS: Record<FeatureName, boolean> = {
  lessonFeedback: false,
  schoolFeedback: true,
};

export const FEATURE_NAMES: FeatureName[] = ["lessonFeedback", "schoolFeedback"];

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

  /**
   * Product switches Dash owns (Gary 2026-09-04). `lessonFeedback` is the
   * school's 评教 screen, off by default because Experiences covers the same
   * ground; `schoolFeedback` is the standalone entry to the school's own
   * feedback channel (the composer always offers it).
   */
  feature(name: FeatureName): boolean {
    const stored = this.get(`feature.${name}`);
    return stored === null ? FEATURE_DEFAULTS[name] : stored === "1";
  }
  setFeature(name: FeatureName, on: boolean): void {
    this.set(`feature.${name}`, on ? "1" : "0");
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
