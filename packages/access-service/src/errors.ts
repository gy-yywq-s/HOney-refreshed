import type { AccessErrorCode } from "@honey/shared/access";

const STATUS: Record<AccessErrorCode, number> = {
  capability_invalid: 401,
  capability_expired: 401,
  access_paused: 423,
  service_unavailable: 503,
  doors_unavailable: 503,
  permits_unavailable: 503,
  permit_not_usable: 409,
  route_not_allowed: 403,
  gate_unknown: 400,
  operation_in_progress: 409,
  operation_not_found: 404,
  operation_not_prepared: 409,
  commit_secret_invalid: 403,
  portal_session_expired: 401,
  portal_rejected: 502,
  outcome_unknown: 502,
  not_sent: 502,
};

export class AccessError extends Error {
  constructor(
    readonly code: AccessErrorCode,
    readonly detail?: Record<string, unknown>,
  ) {
    super(code);
    this.name = "AccessError";
  }
  get status(): number {
    return STATUS[this.code];
  }
  toJSON(): { error: AccessErrorCode } & Record<string, unknown> {
    return { error: this.code, ...(this.detail ?? {}) };
  }
}
