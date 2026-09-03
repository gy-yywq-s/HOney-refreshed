// Typed, allowlisted portal calls (spec §16.3): the service can reach the
// configured portal origin and nothing else. The egress guard wraps fetch
// and refuses any other origin BEFORE a connection is attempted — a
// configuration mistake cannot turn this process into a proxy. Connections
// to the portal stay warm: Node's global fetch keeps connections alive in its
// dispatcher pool, and bootstrap makes one safe read so the final tap reuses
// an open connection.

import { AsyncLocalStorage } from "node:async_hooks";
import { PortalApi, PortalHttp, retrySafeRead, type UserInfoWire } from "@honey/portal-connector";
import type { DoorOptionWire, ExitPermitWire } from "@honey/shared";

export class EgressRefused extends Error {
  constructor(readonly origin: string) {
    super(`egress refused: ${origin}`);
    this.name = "EgressRefused";
  }
}

/**
 * Whether a request never left this process: refused by the egress guard,
 * or the connection could not be established (no DNS, refused, unreachable,
 * TLS handshake failed). Anything after that — a reset mid-flight, a
 * timeout — is an UNKNOWN outcome, never "not sent".
 */
const NOT_SENT_CODES = new Set(["ECONNREFUSED", "ENOTFOUND", "EAI_AGAIN", "ENETUNREACH", "EHOSTUNREACH", "UND_ERR_CONNECT_TIMEOUT", "ERR_TLS_CERT_ALTNAME_INVALID", "CERT_HAS_EXPIRED", "DEPTH_ZERO_SELF_SIGNED_CERT", "SELF_SIGNED_CERT_IN_CHAIN", "UNABLE_TO_VERIFY_LEAF_SIGNATURE"]);
export function wasNeverSent(e: unknown): boolean {
  if (e instanceof EgressRefused) return true;
  const cause = (e as { cause?: { code?: string } })?.cause;
  return typeof cause?.code === "string" && NOT_SENT_CODES.has(cause.code);
}

/** Dispatch-scoped record of whether the wire was ever reached (read by the engine after a failure). */
export interface DispatchTrace {
  neverSent: boolean;
}
const traceStore = new AsyncLocalStorage<DispatchTrace>();

/** A fetch that only ever connects to the allowlisted origins. */
export function guardedFetch(allowed: readonly string[], base: typeof fetch = fetch): typeof fetch {
  const allowedSet = new Set(allowed);
  return (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === "string" ? new URL(input) : input instanceof URL ? input : new URL(input.url);
    const trace = traceStore.getStore();
    if (!allowedSet.has(url.origin)) {
      if (trace) trace.neverSent = true;
      throw new EgressRefused(url.origin);
    }
    try {
      return await base(input, init);
    } catch (e) {
      if (trace && wasNeverSent(e)) trace.neverSent = true;
      throw e;
    }
  }) as typeof fetch;
}

/** Run one dispatch and learn, on failure, whether it ever reached the wire. */
export async function tracedDispatch<T>(fn: () => Promise<T>): Promise<{ ok: true; value: T } | { ok: false; error: unknown; neverSent: boolean }> {
  const trace: DispatchTrace = { neverSent: false };
  try {
    const value = await traceStore.run(trace, fn);
    return { ok: true, value };
  } catch (error) {
    return { ok: false, error, neverSent: trace.neverSent };
  }
}

export interface PortalClientOptions {
  baseUrl: string;
  allowedOrigins: readonly string[];
  /** Test hook: a plain fetch for the mock portal (http). */
  fetchImpl?: typeof fetch;
  timeoutMs?: number;
}

export class AccessPortalClient {
  readonly api: PortalApi;

  constructor(opts: PortalClientOptions) {
    const guarded = guardedFetch(opts.allowedOrigins, opts.fetchImpl ?? fetch);
    this.api = new PortalApi(new PortalHttp({ baseUrl: opts.baseUrl, fetchImpl: guarded, timeoutMs: opts.timeoutMs ?? 10_000 }));
  }

  /** Warm DNS/TLS during bootstrap so the final tap does not pay for it. */
  async warm(token: string): Promise<UserInfoWire> {
    return retrySafeRead(() => this.api.userInfo(token));
  }

  doors(token: string): Promise<DoorOptionWire[]> {
    return retrySafeRead(() => this.api.doorList(token));
  }

  permits(token: string): Promise<ExitPermitWire[]> {
    return retrySafeRead(() => this.api.permitList(token));
  }

  /** NON-IDEMPOTENT: exactly one attempt, never replayed by this service. */
  openDoor(token: string, recordId: number, doorKey: string): Promise<void> {
    return this.api.openDoor(token, recordId, doorKey);
  }

  addPermit(token: string, startTime: string, endTime: string, note: string): Promise<void> {
    return this.api.addPermit(token, startTime, endTime, note);
  }

  deletePermit(token: string, recordId: number): Promise<void> {
    return this.api.deletePermit(token, recordId);
  }
}
