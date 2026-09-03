// Core's authenticated proxy to Community's internal admin surface (spec
// §24.2 pattern): the Dash is a Core feature; Community exposes its switches
// only on loopback with a dedicated internal secret. No request here carries
// an account: the proxy sends the secret and the operation, nothing else.

export interface CommunityStatus {
  counts: { published: number; openReports: number; suspended: number };
  policyVersion: number;
  killSwitches: Record<string, boolean>;
  cooldownHours: number;
  reactionMinCount: number;
  llm: { configured: boolean; model: string };
}

export class CommunityAdminClient {
  constructor(
    private readonly baseUrl: string,
    private readonly secret: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  private async call<T>(method: "GET" | "POST", path: string, body?: unknown): Promise<T> {
    const res = await this.fetchImpl(`${this.baseUrl}${path}`, {
      method,
      headers: { "x-honey-internal": this.secret, ...(body !== undefined ? { "content-type": "application/json" } : {}) },
      ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`community admin ${path}: ${res.status}`);
    return (await res.json()) as T;
  }

  status(): Promise<CommunityStatus> {
    return this.call("GET", "/internal/admin/status");
  }
  setKillSwitch(name: string, on: boolean): Promise<{ ok: boolean }> {
    return this.call("POST", "/internal/admin/kill-switch", { name, on });
  }
  setFrozenEntity(entityKey: string, frozen: boolean): Promise<{ ok: boolean }> {
    return this.call("POST", "/internal/admin/freeze-entity", { entityKey, frozen });
  }
  setReactionMinCount(minCount: number): Promise<{ ok: boolean }> {
    return this.call("POST", "/internal/admin/reaction-min-count", { minCount });
  }
  setCooldownHours(hours: number): Promise<{ ok: boolean }> {
    return this.call("POST", "/internal/admin/cooldown-hours", { hours });
  }
  setLlm(input: { apiKey?: string; model?: string }): Promise<{ ok: boolean; configured: boolean }> {
    return this.call("POST", "/internal/admin/llm", input);
  }
  testLlm(): Promise<{ ok: boolean; latencyMs: number | null; model: string | null }> {
    return this.call("POST", "/internal/admin/llm/test");
  }
  reports(): Promise<{ reports: { id: string; experience_id: string; category: string; outcome: string | null; created_at: number }[] }> {
    return this.call("GET", "/internal/admin/reports");
  }
}
