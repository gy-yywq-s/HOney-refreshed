// Core's proxy to the Access Service's internal admin surface (loopback +
// internal secret): the Dash switch and status. No account crosses.

import type { AccessAdminStatus } from "@honey/shared/access";

export class AccessAdminClient {
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
    if (!res.ok) throw new Error(`access admin ${path}: ${res.status}`);
    return (await res.json()) as T;
  }

  status(): Promise<AccessAdminStatus> {
    return this.call("GET", "/internal/admin/status");
  }
  setEnabled(on: boolean): Promise<{ ok: boolean; enabled: boolean }> {
    return this.call("POST", "/internal/admin/enabled", { on });
  }
  journal(): Promise<{ operations: unknown[] }> {
    return this.call("GET", "/internal/admin/journal");
  }
}
