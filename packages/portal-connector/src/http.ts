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

/** True when a non-JSON body looks like the portal's maintenance page. */
export function looksLikeMaintenance(rawText: string): boolean {
  const lower = rawText.slice(0, 2000).toLowerCase();
  return MAINTENANCE_SIGNATURES.some((s) => lower.includes(s));
}

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
    let rawText: string;
    try {
      res = await this.fetchImpl(`${this.baseUrl}${args.path}`, {
        method: args.method,
        headers,
        body: args.jsonBody === undefined ? null : JSON.stringify(args.jsonBody),
        signal: AbortSignal.timeout(args.timeoutMs ?? this.timeoutMs),
      });
      // The abort signal can also fire while the BODY streams; a mid-body
      // timeout/reset must classify as timeout/network, never as schema drift.
      rawText = await res.text();
    } catch (e) {
      if (e instanceof DOMException && e.name === "TimeoutError") {
        throw timeoutError(args.mutation === true);
      }
      throw networkUnavailable();
    }
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
    if (resp.httpStatus === 401) {
      // 401 without the portal envelope (proxy/LB interference): treat as an
      // availability problem, not incompatibility — reserve circuit-breaking
      // for repeated parser failures per the failure matrix.
      throw serverUnavailable(resp.httpStatus);
    }
    if (resp.body === undefined) {
      if (looksLikeMaintenance(resp.rawText)) throw serverUnavailable(resp.httpStatus);
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
      const info =
        e instanceof Error && "info" in e
          ? (e as { info?: { kind?: string; retryable?: boolean } }).info
          : undefined;
      // sessionExpired is retryable-by-contract but must reach the coordinator
      // (which owns re-auth) rather than being retried blindly here.
      const retryable = info?.retryable === true && info.kind !== "sessionExpired";
      if (!retryable || attempt === retries) throw e;
      await new Promise((r) => setTimeout(r, 150 * (attempt + 1) + Math.random() * 100));
    }
  }
  throw lastErr;
}
