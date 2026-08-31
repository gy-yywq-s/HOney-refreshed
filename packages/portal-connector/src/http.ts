import { isUnauthorized } from "@honey/shared";
import {
  networkUnavailable,
  schemaIncompatible,
  serverUnavailable,
  sessionExpired,
  timeoutError,
} from "./errors.js";

// The portal's own web wrappers ship no client timeout at all, so we always
// supply our own. Mutations get `outcomeUnknown` on timeout: the request may
// have been applied even though we never saw the response.

export interface HttpOptions {
  baseUrl: string;
  /** Per-request timeout in ms. */
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export interface PortalResponse {
  httpStatus: number;
  body: unknown;
  rawText: string;
}

const MAINTENANCE_SIGNATURES = ["maintenance", "升级维护", "系统维护"];

export class PortalHttp {
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: HttpOptions) {
    this.baseUrl = opts.baseUrl.replace(/\/$/, "");
    this.timeoutMs = opts.timeoutMs ?? 10_000;
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  /**
   * Perform a request and return status + parsed body. Transport failures map
   * to typed connector errors; JSON is parsed leniently (portal sometimes
   * serves HTML error/maintenance pages with 200).
   */
  async request(args: {
    method: "GET" | "POST";
    path: string;
    token?: string;
    jsonBody?: unknown;
    mutation?: boolean;
    timeoutMs?: number;
  }): Promise<PortalResponse> {
    const headers: Record<string, string> = { Accept: "application/json" };
    // Raw token — the portal does NOT use a "Bearer " prefix.
    if (args.token !== undefined) headers["Authorization"] = args.token;
    if (args.jsonBody !== undefined) headers["Content-Type"] = "application/json";

    let res: Response;
    try {
      res = await this.fetchImpl(`${this.baseUrl}${args.path}`, {
        method: args.method,
        headers,
        body: args.jsonBody === undefined ? null : JSON.stringify(args.jsonBody),
        signal: AbortSignal.timeout(args.timeoutMs ?? this.timeoutMs),
      });
    } catch (e) {
      if (e instanceof DOMException && e.name === "TimeoutError") {
        throw timeoutError(args.mutation === true);
      }
      throw networkUnavailable();
    }

    const rawText = await res.text().catch(() => "");
    let body: unknown = undefined;
    try {
      body = rawText.length > 0 ? JSON.parse(rawText) : undefined;
    } catch {
      body = undefined;
    }
    return { httpStatus: res.status, body, rawText };
  }

  /**
   * Shared response triage for authenticated endpoints:
   * 5xx → serverUnavailable; 401+portal envelope → sessionExpired;
   * 200 + maintenance HTML → serverUnavailable; 200 + other non-JSON → schemaIncompatible.
   * Returns the parsed JSON body otherwise.
   */
  triage(resp: PortalResponse, endpoint: string): unknown {
    if (resp.httpStatus >= 500) throw serverUnavailable(resp.httpStatus);
    if (isUnauthorized(resp.httpStatus, resp.body)) throw sessionExpired();
    if (resp.body === undefined) {
      const lower = resp.rawText.slice(0, 2000).toLowerCase();
      if (MAINTENANCE_SIGNATURES.some((s) => lower.includes(s))) {
        throw serverUnavailable(resp.httpStatus);
      }
      throw schemaIncompatible(endpoint);
    }
    return resp.body;
  }
}

/** Retry helper for safe reads only: ≤2 retries on network/5xx, none on schema errors. */
export async function retrySafeRead<T>(op: () => Promise<T>, retries = 2): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await op();
    } catch (e) {
      lastErr = e;
      const retryable =
        e instanceof Error &&
        "info" in e &&
        typeof (e as { info?: { kind?: string } }).info === "object" &&
        ((e as { info: { kind: string } }).info.kind === "networkUnavailable" ||
          (e as { info: { kind: string } }).info.kind === "serverUnavailable" ||
          (e as { info: { kind: string } }).info.kind === "timeout");
      if (!retryable || attempt === retries) throw e;
      await new Promise((r) => setTimeout(r, 150 * (attempt + 1) + Math.random() * 100));
    }
  }
  throw lastErr;
}
