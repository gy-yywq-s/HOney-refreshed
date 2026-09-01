import type { DatabaseSync } from "node:sqlite";
import { open, seal } from "../crypto.js";

// Operational settings (kill switches §23, standalone-eligibility modes, LLM
// config). Stored in the settings table; the OpenRouter key is sealed at rest.

export type KillSwitch =
  | "DISABLE_NEW_PUBLICATIONS"
  | "DISABLE_REACTIONS"
  | "DISABLE_REPORTS"
  | "HIDE_PUBLIC_EXPERIENCES"
  | "PRIVATE_NOTES_ONLY_MODE";

export type StandaloneMode = "verified" | "open" | "invite" | "closed";

export class SettingsService {
  constructor(private readonly db: DatabaseSync, private readonly sealKey: Buffer) {}

  get(key: string): string | null {
    const row = this.db.prepare("SELECT value FROM settings WHERE key = ?").get(key) as
      | unknown as { value: string } | undefined;
    return row?.value ?? null;
  }

  set(key: string, value: string): void {
    this.db
      .prepare(
        "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
      )
      .run(key, value);
  }

  delete(key: string): void {
    this.db.prepare("DELETE FROM settings WHERE key = ?").run(key);
  }

  // ---- kill switches ----
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

  // ---- standalone-object eligibility (Gary's decisions doc) ----
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

  // ---- moderation LLM ----
  llmConfig(env: NodeJS.ProcessEnv = process.env): { apiKey: string; model: string; timeoutMs: number } | null {
    const sealed = this.get("llm.apiKeySealed");
    let apiKey = env.OPENROUTER_API_KEY ?? "";
    if (sealed) {
      try {
        apiKey = open(Buffer.from(sealed, "base64"), this.sealKey);
      } catch {
        /* fall back to env */
      }
    }
    if (!apiKey) return null;
    return {
      apiKey,
      model: this.get("llm.model") ?? "mistralai/mistral-small-3.2-24b-instruct",
      timeoutMs: Number(this.get("llm.timeoutMs") ?? 8000),
    };
  }
  setLlmKey(apiKey: string): void {
    this.set("llm.apiKeySealed", seal(apiKey, this.sealKey).toString("base64"));
  }
  setLlmModel(model: string): void {
    this.set("llm.model", model);
  }

  /** Small-cohort reaction-count hiding threshold (App A §10). */
  reactionMinCount(): number {
    return Number(this.get("reactions.minCount") ?? 0);
  }
}
