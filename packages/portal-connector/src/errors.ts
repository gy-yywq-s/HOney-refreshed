import type { ConnectorError } from "@honey/shared";

/** Error class carrying a typed ConnectorError so callers can switch on `kind`. */
export class PortalError extends Error {
  readonly info: ConnectorError;

  constructor(info: ConnectorError, message?: string) {
    super(message ?? info.kind);
    this.name = "PortalError";
    this.info = info;
  }

  get kind(): ConnectorError["kind"] {
    return this.info.kind;
  }

  get retryable(): boolean {
    return "retryable" in this.info ? this.info.retryable : false;
  }
}

export const networkUnavailable = () =>
  new PortalError({ kind: "networkUnavailable", retryable: true });

export const timeoutError = (outcomeUnknown = false) =>
  new PortalError({ kind: "timeout", retryable: true, outcomeUnknown });

export const serverUnavailable = (httpStatus?: number) =>
  new PortalError(
    httpStatus === undefined
      ? { kind: "serverUnavailable", retryable: true }
      : { kind: "serverUnavailable", retryable: true, httpStatus },
  );

export const sessionExpired = () =>
  new PortalError({ kind: "sessionExpired", retryable: true });

export const credentialsRejected = () =>
  new PortalError({ kind: "credentialsRejected", retryable: false });

export const userActionRequired = (
  reason: "captcha" | "mfa" | "passwordChanged" | "unknown",
) => new PortalError({ kind: "userActionRequired", reason });

export const operationRejected = (endpoint: string, status?: number, reason?: string, shape?: string) =>
  new PortalError({
    kind: "operationRejected",
    endpoint,
    ...(status === undefined ? {} : { status }),
    ...(reason ? { reason } : {}),
    ...(shape ? { shape } : {}),
  });

function shortText(v: unknown): string | undefined {
  if (typeof v === "number") return String(v);
  if (typeof v !== "string") return undefined;
  const text = v.trim();
  return text && text.length <= 200 ? text : undefined;
}

/**
 * The portal's refusal text (never a body dump): `message` when it is a short
 * string; otherwise the first text found in the places the portal is known
 * to put words — `data` as a string, `data.message|msg|reason|error|info`,
 * `msg`/`error` at the top, or a `message` object's own text fields.
 */
export function refusalReason(env: Record<string, unknown>): string | undefined {
  const fromObject = (o: unknown): string | undefined => {
    if (!o || typeof o !== "object" || Array.isArray(o)) return undefined;
    const r = o as Record<string, unknown>;
    for (const k of ["message", "msg", "reason", "error", "info", "tip", "text"]) {
      const t = shortText(r[k]);
      if (t) return t;
    }
    return undefined;
  };
  return (
    shortText(env.message) ??
    shortText(env.data) ??
    fromObject(env.data) ??
    shortText(env.msg) ??
    shortText(env.error) ??
    fromObject(env.message) ??
    (Array.isArray(env.message) ? shortText(env.message.map((x) => (typeof x === "string" ? x : "")).join(" ").trim()) : undefined)
  );
}

/** The envelope's layout as types only (keys and value kinds, no values) — safe to log so an unknown refusal shape can be learned. */
export function envelopeShape(env: Record<string, unknown>, depth = 0): string {
  return Object.entries(env)
    .map(([k, v]) => {
      const kind = v === null ? "null" : Array.isArray(v) ? `array(${v.length})` : typeof v;
      if (kind === "object" && depth < 1) return `${k}:{${envelopeShape(v as Record<string, unknown>, depth + 1)}}`;
      if (kind === "string") return `${k}:string(${(v as string).length})`;
      return `${k}:${kind}`;
    })
    .join(",");
}

export const schemaIncompatible = (endpoint: string) =>
  new PortalError({ kind: "schemaIncompatible", endpoint });

export function isPortalError(e: unknown): e is PortalError {
  return e instanceof PortalError;
}
