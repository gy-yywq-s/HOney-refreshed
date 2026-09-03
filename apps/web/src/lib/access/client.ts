// Web Access client (spec §20–§22). Core hands out a short-lived capability;
// every call to the Access Service carries it in a header and NO HOney
// credentials (`credentials: "omit"`; the edge strips identity anyway). A
// physical action is prepare → confirm → commit, and commit is a stream we
// read line by line; if the stream is lost we ask for the journal's state
// rather than guessing — and never commit twice.

import { api, ApiError } from "../../api/client";
import type { AccessBootstrap, AccessErrorCode, AccessProgressEvent, ApplyPermitInput, OperationStatus, PrepareOpenInput, PreparedOpenOperation, ProgressStage } from "@honey/shared/access";

export type AccessFailure = AccessErrorCode | "network" | "no_school_connection" | "portal_reconnect_required" | "access_unavailable" | "not_authenticated";

export class AccessClientError extends Error {
  constructor(
    readonly code: AccessFailure,
    readonly detail: Record<string, unknown> = {},
  ) {
    super(code);
    this.name = "AccessClientError";
  }
}

const CAPABILITY_HEADER = "Access-Capability";
const COMMIT_HEADER = "Access-Commit";

function nonce(): string {
  const b = crypto.getRandomValues(new Uint8Array(12));
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

/** The stage a journal state maps to when we had to ask instead of listen. */
export function stageForState(state: OperationStatus["state"]): ProgressStage {
  switch (state) {
    case "CONFIRMED":
      return "confirmed";
    case "REJECTED":
      return "rejected";
    case "NOT_SENT":
    case "PAUSED":
    case "EXPIRED":
      return "not_sent";
    case "OUTCOME_UNKNOWN":
      return "outcome_unknown";
    case "WAITING_FOR_SCHOOL":
      return "waiting_for_school";
    case "DISPATCHING":
      return "sending";
    default:
      return "accepted";
  }
}

export const STAGE_COPY: Record<ProgressStage, string> = {
  accepted: "Request accepted.",
  sending: "Sending to the school gate system…",
  waiting_for_school: "Waiting for the school to confirm…",
  confirmed: "Done. The school confirmed.",
  rejected: "The school declined this request. Nothing was opened.",
  not_sent: "Nothing was sent to the school.",
  outcome_unknown: "The school did not answer. Check the gate before trying again.",
};

class AccessClient {
  private capability: { value: string; expiresAt: number } | null = null;
  private fetchFn: typeof fetch = (input, init) => fetch(input, init);

  /** Tests can swap the transport. */
  useFetch(fn: typeof fetch): void {
    this.fetchFn = fn;
  }

  forget(): void {
    this.capability = null;
  }

  private async cap(): Promise<string> {
    if (this.capability && this.capability.expiresAt - Date.now() > 30_000) return this.capability.value;
    let r: Awaited<ReturnType<typeof api.accessSession>>;
    try {
      r = await api.accessSession();
    } catch (e) {
      if (e instanceof ApiError) throw new AccessClientError(e.code === "network_error" ? "network" : e.status === 401 ? "not_authenticated" : "access_unavailable");
      throw new AccessClientError("network");
    }
    if (!r.ok) throw new AccessClientError(r.error);
    this.capability = { value: r.capability, expiresAt: r.expiresAt };
    return r.capability;
  }

  private async call<T>(method: "GET" | "POST", path: string, body?: unknown, retryCapability = true): Promise<T> {
    const cap = await this.cap();
    const headers: Record<string, string> = { Accept: "application/json", [CAPABILITY_HEADER]: cap };
    if (body !== undefined) headers["Content-Type"] = "application/json";
    let res: Response;
    try {
      res = await this.fetchFn(path, { method, headers, credentials: "omit", ...(body !== undefined ? { body: JSON.stringify(body) } : {}) });
    } catch {
      throw new AccessClientError("network");
    }
    if (!res.ok) {
      const j = (await res.json().catch(() => ({}))) as { error?: AccessErrorCode } & Record<string, unknown>;
      if (res.status === 401 && retryCapability && (j.error === "capability_expired" || j.error === "capability_invalid")) {
        this.capability = null;
        return this.call<T>(method, path, body, false);
      }
      throw new AccessClientError(j.error ?? "service_unavailable", j);
    }
    return (await res.json()) as T;
  }

  bootstrap(): Promise<AccessBootstrap> {
    return this.call("GET", "/access/bootstrap");
  }

  prepareOpen(input: Omit<PrepareOpenInput, "clientNonce">): Promise<PreparedOpenOperation> {
    return this.call("POST", "/access/operations/open/prepare", { ...input, clientNonce: nonce() });
  }

  preparePermit(input: Omit<ApplyPermitInput, "clientNonce">): Promise<PreparedOpenOperation> {
    return this.call("POST", "/access/operations/permit/prepare", { ...input, clientNonce: nonce() });
  }

  prepareWithdraw(recordId: number): Promise<PreparedOpenOperation> {
    return this.call("POST", "/access/operations/withdraw/prepare", { recordId, clientNonce: nonce() });
  }

  status(operationId: string): Promise<OperationStatus> {
    return this.call("GET", `/access/operations/${encodeURIComponent(operationId)}`);
  }

  /**
   * Commit once and follow the stream. Resolves with the terminal event. If
   * the stream breaks before a terminal event, the journal is polled — the
   * request is never re-sent from here.
   */
  async commit(op: PreparedOpenOperation, onEvent: (e: AccessProgressEvent) => void): Promise<AccessProgressEvent> {
    const cap = await this.cap();
    let res: Response;
    try {
      res = await this.fetchFn(`/access/operations/${encodeURIComponent(op.operationId)}/commit`, {
        method: "POST",
        headers: { Accept: "application/x-ndjson", [CAPABILITY_HEADER]: cap, [COMMIT_HEADER]: op.commitSecret },
        credentials: "omit",
      });
    } catch {
      // Unknown whether the commit reached the service: ask, don't resend.
      return this.settleByStatus(op.operationId, onEvent);
    }
    if (!res.ok) {
      const j = (await res.json().catch(() => ({}))) as { error?: AccessErrorCode } & Record<string, unknown>;
      throw new AccessClientError(j.error ?? "service_unavailable", j);
    }
    let last: AccessProgressEvent | null = null;
    try {
      const reader = res.body!.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      for (;;) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        let nl: number;
        while ((nl = buffer.indexOf("\n")) >= 0) {
          const line = buffer.slice(0, nl).trim();
          buffer = buffer.slice(nl + 1);
          if (!line) continue;
          const event = JSON.parse(line) as AccessProgressEvent;
          last = event;
          onEvent(event);
          if (event.terminal) return event;
        }
      }
    } catch {
      /* stream lost: fall through to the journal */
    }
    if (last?.terminal) return last;
    return this.settleByStatus(op.operationId, onEvent);
  }

  private async settleByStatus(operationId: string, onEvent: (e: AccessProgressEvent) => void): Promise<AccessProgressEvent> {
    const started = Date.now();
    for (;;) {
      let status: OperationStatus | null = null;
      try {
        status = await this.status(operationId);
      } catch {
        status = null;
      }
      const stage = status ? stageForState(status.state) : null;
      if (stage && (stage === "confirmed" || stage === "rejected" || stage === "not_sent" || stage === "outcome_unknown")) {
        const event: AccessProgressEvent = { stage, elapsedMs: Date.now() - started, message: STAGE_COPY[stage], terminal: true };
        onEvent(event);
        return event;
      }
      if (Date.now() - started > 30_000) {
        const event: AccessProgressEvent = { stage: "outcome_unknown", elapsedMs: Date.now() - started, message: STAGE_COPY.outcome_unknown, terminal: true };
        onEvent(event);
        return event;
      }
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
}

export const accessClient = new AccessClient();

/** What the student is told when nothing physical happened (spec §25). Every line says whether anything was sent. */
export function describeAccessFailure(code: AccessFailure): { text: string; reconnect?: boolean } {
  switch (code) {
    case "no_school_connection":
      return { text: "Connect your school account first. Nothing was sent.", reconnect: true };
    case "portal_reconnect_required":
    case "portal_session_expired":
      return { text: "Your school session has expired. Nothing was sent. Reconnect in Settings › School connection.", reconnect: true };
    case "not_authenticated":
      return { text: "You are signed out of HOney. Nothing was sent." };
    case "access_paused":
      return { text: "Web Access is paused right now. Nothing was sent." };
    case "network":
    case "access_unavailable":
    case "service_unavailable":
      return { text: "Web Access can't reach the school right now. Nothing was sent." };
    case "doors_unavailable":
      return { text: "The gate list couldn't be read. Nothing was sent." };
    case "permits_unavailable":
      return { text: "Your permits couldn't be read. Nothing was sent." };
    case "permit_not_usable":
      return { text: "This permit can't be used right now. Nothing was sent." };
    case "route_not_allowed":
      return { text: "This route isn't available for your account. Nothing was sent." };
    case "gate_unknown":
      return { text: "That gate isn't on the school's list any more. Nothing was sent." };
    case "operation_in_progress":
      return { text: "Another request is still in progress. Wait for it to finish." };
    case "operation_not_prepared":
      return { text: "This confirmation expired. Nothing was sent. Start again." };
    case "commit_secret_invalid":
    case "operation_not_found":
      return { text: "This confirmation is no longer valid. Nothing was sent." };
    case "capability_invalid":
    case "capability_expired":
      return { text: "Your access session expired. Nothing was sent. Try again." };
    case "portal_rejected":
      return { text: "The school declined this request. Nothing was opened." };
    case "outcome_unknown":
      return { text: STAGE_COPY.outcome_unknown };
    case "not_sent":
      return { text: STAGE_COPY.not_sent };
  }
}
