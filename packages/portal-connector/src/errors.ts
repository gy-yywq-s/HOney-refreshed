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

export const operationRejected = (endpoint: string, status?: number, reason?: string) =>
  new PortalError({
    kind: "operationRejected",
    endpoint,
    ...(status === undefined ? {} : { status }),
    ...(reason ? { reason } : {}),
  });

/** The portal's refusal text: its `message` when it is a short string (never a body dump). */
export function refusalReason(env: { message?: unknown }): string | undefined {
  const m = env.message;
  if (typeof m !== "string") return undefined;
  const text = m.trim();
  return text && text.length <= 200 ? text : undefined;
}

export const schemaIncompatible = (endpoint: string) =>
  new PortalError({ kind: "schemaIncompatible", endpoint });

export function isPortalError(e: unknown): e is PortalError {
  return e instanceof PortalError;
}
