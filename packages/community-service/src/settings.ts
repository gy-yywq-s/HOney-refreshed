import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";

// Community-side operational settings: kill switches, frozen entities,
// reaction threshold, cooling-off hours, the moderation model + key (sealed
// with Community's own key). Set through Core's Dash proxy only.

export type KillSwitch = "DISABLE_NEW_PUBLICATIONS" | "DISABLE_REACTIONS" | "DISABLE_REPORTS" | "HIDE_PUBLIC_EXPERIENCES";
export const KILL_SWITCHES: KillSwitch[] = ["DISABLE_NEW_PUBLICATIONS", "DISABLE_REACTIONS", "DISABLE_REPORTS", "HIDE_PUBLIC_EXPERIENCES"];

function seal(plaintext: string, key: Buffer): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), enc]).toString("base64");
}

function open(sealed: string, key: Buffer): string {
  const buf = Buffer.from(sealed, "base64");
  const decipher = createDecipheriv("aes-256-gcm", key, buf.subarray(0, 12));
  decipher.setAuthTag(buf.subarray(12, 28));
  return Buffer.concat([decipher.update(buf.subarray(28)), decipher.final()]).toString("utf8");
}

export class CommunitySettings {
  constructor(
    private readonly db: DatabaseSync,
    private readonly sealKey: Buffer,
    private readonly envApiKey: string,
  ) {}

  get(key: string): string | null {
    const row = this.db.prepare("SELECT value FROM settings WHERE key = ?").get(key) as { value: string } | undefined;
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
  reactionMinCount(): number {
    return Number(this.get("reactions.minCount") ?? 0);
  }
  cooldownHours(): number {
    const n = Number(this.get("cooldown.hours"));
    return Number.isFinite(n) && n > 0 ? n : 24;
  }
  llmConfig(): { apiKey: string; model: string; timeoutMs: number } | null {
    const sealed = this.get("llm.apiKeySealed");
    let apiKey = this.envApiKey;
    if (sealed) {
      try {
        apiKey = open(sealed, this.sealKey);
      } catch {
        /* fall back to the environment key */
      }
    }
    if (!apiKey) return null;
    return { apiKey, model: this.get("llm.model") ?? "mistralai/mistral-small-3.2-24b-instruct", timeoutMs: Number(this.get("llm.timeoutMs") ?? 8000) };
  }
  setLlmKey(apiKey: string): void {
    this.set("llm.apiKeySealed", seal(apiKey, this.sealKey));
  }
  llmModel(): string {
    return this.get("llm.model") ?? "mistralai/mistral-small-3.2-24b-instruct";
  }
}
