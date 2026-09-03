// The Access engine (spec §19–23): bootstrap reads, prepare (fresh checks +
// a one-time commit secret), commit (claim exactly once, dispatch exactly
// once, stream the truth), status. A physical request is never retried by
// this process, a paused switch stops it before dispatch, and a client that
// disconnects mid-stream does not cancel a dispatch already on the wire.

import { isPortalError } from "@honey/portal-connector";
import {
  COMMUTER_RECORD_ID,
  doorFromWire,
  isOpenable,
  permitFromWire,
  type AccessBootstrap,
  type AccessProgressEvent,
  type ApplyPermitInput,
  type Door,
  type OperationStatus,
  type Permit,
  type PrepareOpenInput,
  type PreparedOpenOperation,
  type ProgressStage,
} from "@honey/shared/access";
import type { VerifiedCapability } from "./capability.js";
import { AccessError } from "./errors.js";
import type { LatencyModel } from "./latency.js";
import { hashSubject, isTerminal, PREPARE_TTL_MS, type OperationKind, type OperationRow, type OperationStore } from "./operation-store.js";
import { tracedDispatch, type AccessPortalClient } from "./portal-client.js";
import type { RuntimePolicy } from "./runtime-policy.js";

export interface EngineDeps {
  store: OperationStore;
  latency: LatencyModel;
  policy: RuntimePolicy;
  portal: AccessPortalClient;
  serviceVersion: string;
  now?: () => number;
}

/** Progress copy (spec §22.2): every line states what is true right now. */
export const PROGRESS_COPY: Record<ProgressStage, string> = {
  accepted: "Request accepted.",
  sending: "Sending to the school gate system…",
  waiting_for_school: "Waiting for the school to confirm…",
  confirmed: "Done. The school confirmed.",
  rejected: "The school declined this request. Nothing was opened.",
  not_sent: "Nothing was sent to the school.",
  outcome_unknown: "The school did not answer. Check the gate before trying again.",
};

const ROUTE_NAMES = { day_student: "Day student", exit_permit: "Exit permit" } as const;
const PERMIT_WINDOW_MAX_MS = 24 * 3600 * 1000;

/** A small async channel: the dispatcher pushes, the HTTP stream drains. */
class Channel<T> {
  private items: T[] = [];
  private waiters: ((v: IteratorResult<T>) => void)[] = [];
  private closed = false;
  push(item: T): void {
    if (this.closed) return;
    const w = this.waiters.shift();
    if (w) w({ value: item, done: false });
    else this.items.push(item);
  }
  close(): void {
    this.closed = true;
    for (const w of this.waiters.splice(0)) w({ value: undefined as never, done: true });
  }
  async *[Symbol.asyncIterator](): AsyncGenerator<T> {
    for (;;) {
      if (this.items.length) {
        yield this.items.shift()!;
        continue;
      }
      if (this.closed) return;
      const next = await new Promise<IteratorResult<T>>((resolve) => this.waiters.push(resolve));
      if (next.done) return;
      yield next.value;
    }
  }
}

export class AccessEngine {
  private readonly now: () => number;
  /** Live streams for operations in flight, so a reconnecting client can re-attach. */
  private readonly streams = new Map<string, { events: AccessProgressEvent[]; channels: Set<Channel<AccessProgressEvent>>; done: boolean }>();
  /** Dispatches on the wire; shutdown waits for them so the journal records their outcome. */
  private readonly inFlight = new Set<Promise<void>>();

  constructor(private readonly deps: EngineDeps) {
    this.now = deps.now ?? (() => Date.now());
  }

  /** Wait (bounded) for in-flight dispatches to settle. */
  async drain(maxMs: number): Promise<void> {
    if (this.inFlight.size === 0) return;
    await Promise.race([Promise.allSettled([...this.inFlight]), new Promise((r) => setTimeout(r, maxMs).unref())]);
  }

  // ---- reads -------------------------------------------------------------

  async bootstrap(cap: VerifiedCapability): Promise<AccessBootstrap> {
    const token = cap.session.token;
    let dayStudent = false;
    try {
      const me = await this.deps.portal.warm(token);
      dayStudent = me.day_student === true || me.day_student === 1;
    } catch (e) {
      if (isPortalError(e) && e.kind === "sessionExpired") throw new AccessError("portal_session_expired");
      throw new AccessError("service_unavailable");
    }
    const [doorsR, permitsR] = await Promise.allSettled([this.deps.portal.doors(token), this.deps.portal.permits(token)]);
    const doors: Door[] = doorsR.status === "fulfilled" ? doorsR.value.map(doorFromWire) : [];
    const permits: Permit[] = permitsR.status === "fulfilled" ? permitsR.value.map(permitFromWire) : [];
    const now = this.now();
    return {
      serviceVersion: this.deps.serviceVersion,
      enabled: this.deps.policy.enabled(),
      identity: { portalStudentId: cap.portalStudentId, dayStudent },
      doors,
      doorsFresh: doorsR.status === "fulfilled",
      permits,
      permitsFresh: permitsR.status === "fulfilled",
      routes: { dayStudent, exitPermit: permits.some((p) => isOpenable(p, now)) },
      eta: { openGate: this.deps.latency.eta("open_gate").label, permit: this.deps.latency.eta("apply_permit").label },
      readAt: now,
    };
  }

  // ---- prepare -----------------------------------------------------------

  private guardPrepare(cap: VerifiedCapability): string {
    if (!this.deps.policy.enabled()) throw new AccessError("access_paused");
    const subjectHash = hashSubject(cap.subject);
    const active = this.deps.store.activeFor(subjectHash);
    if (active) {
      if (active.state === "PREPARED" && this.now() - active.prepared_at > PREPARE_TTL_MS) {
        this.deps.store.transition(active.id, "EXPIRED", this.now(), { outcomeCode: "prepare_expired" });
      } else {
        throw new AccessError("operation_in_progress", { operationId: active.id });
      }
    }
    return subjectHash;
  }

  async prepareOpen(cap: VerifiedCapability, input: PrepareOpenInput): Promise<PreparedOpenOperation> {
    const subjectHash = this.guardPrepare(cap);
    const token = cap.session.token;
    if (input.route !== "day_student" && input.route !== "exit_permit") throw new AccessError("route_not_allowed");
    if (typeof input.gateKey !== "string" || !input.gateKey) throw new AccessError("gate_unknown");

    // Fresh reads: physical authority is never granted from cached state.
    let doors: Door[];
    try {
      doors = (await this.deps.portal.doors(token)).map(doorFromWire);
    } catch (e) {
      if (isPortalError(e) && e.kind === "sessionExpired") throw new AccessError("portal_session_expired");
      throw new AccessError("doors_unavailable");
    }
    const door = doors.find((d) => d.key === input.gateKey);
    if (!door) throw new AccessError("gate_unknown");

    let permitRecordId = COMMUTER_RECORD_ID;
    if (input.route === "day_student") {
      let me;
      try {
        me = await this.deps.portal.warm(token);
      } catch (e) {
        if (isPortalError(e) && e.kind === "sessionExpired") throw new AccessError("portal_session_expired");
        throw new AccessError("service_unavailable");
      }
      if (!(me.day_student === true || me.day_student === 1)) throw new AccessError("route_not_allowed");
    } else {
      if (typeof input.permitRecordId !== "number") throw new AccessError("permit_not_usable");
      let permits: Permit[];
      try {
        permits = (await this.deps.portal.permits(token)).map(permitFromWire);
      } catch (e) {
        if (isPortalError(e) && e.kind === "sessionExpired") throw new AccessError("portal_session_expired");
        throw new AccessError("permits_unavailable");
      }
      const permit = permits.find((p) => p.recordId === input.permitRecordId);
      if (!permit || !isOpenable(permit, this.now())) throw new AccessError("permit_not_usable");
      permitRecordId = permit.recordId;
    }

    const now = this.now();
    const { row, commitSecret } = this.deps.store.prepare({ subjectHash, kind: "open_gate", gateKey: door.key, permitRecordId, clientNonce: input.clientNonce, payload: { gateDisplayName: door.displayName, route: input.route }, now });
    return {
      operationId: row.id,
      commitSecret,
      expiresAt: now + PREPARE_TTL_MS,
      gateDisplayName: door.displayName,
      routeDisplayName: ROUTE_NAMES[input.route],
      etaLabel: this.deps.latency.eta("open_gate").label,
    };
  }

  async preparePermit(cap: VerifiedCapability, input: ApplyPermitInput): Promise<PreparedOpenOperation> {
    const subjectHash = this.guardPrepare(cap);
    const re = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/;
    if (typeof input.startTime !== "string" || typeof input.endTime !== "string" || !re.test(input.startTime) || !re.test(input.endTime)) throw new AccessError("permit_not_usable", { reason: "time_format" });
    const start = Date.parse(input.startTime.replace(" ", "T") + "+08:00");
    const end = Date.parse(input.endTime.replace(" ", "T") + "+08:00");
    if (!(end > start) || end - start > PERMIT_WINDOW_MAX_MS) throw new AccessError("permit_not_usable", { reason: "time_window" });
    const note = typeof input.note === "string" ? input.note.trim().slice(0, 60) : "";
    if (!note) throw new AccessError("permit_not_usable", { reason: "note_required" });
    const now = this.now();
    const { row, commitSecret } = this.deps.store.prepare({ subjectHash, kind: "apply_permit", clientNonce: input.clientNonce, payload: { startTime: input.startTime, endTime: input.endTime, note }, now });
    return { operationId: row.id, commitSecret, expiresAt: now + PREPARE_TTL_MS, gateDisplayName: "", routeDisplayName: "Exit permit request", etaLabel: this.deps.latency.eta("apply_permit").label };
  }

  async prepareWithdraw(cap: VerifiedCapability, input: { recordId: number; clientNonce: string }): Promise<PreparedOpenOperation> {
    const subjectHash = this.guardPrepare(cap);
    if (typeof input.recordId !== "number") throw new AccessError("permit_not_usable");
    let permits: Permit[];
    try {
      permits = (await this.deps.portal.permits(cap.session.token)).map(permitFromWire);
    } catch (e) {
      if (isPortalError(e) && e.kind === "sessionExpired") throw new AccessError("portal_session_expired");
      throw new AccessError("permits_unavailable");
    }
    const permit = permits.find((p) => p.recordId === input.recordId);
    if (!permit || permit.state !== "pending") throw new AccessError("permit_not_usable");
    const now = this.now();
    const { row, commitSecret } = this.deps.store.prepare({ subjectHash, kind: "withdraw_permit", permitRecordId: permit.recordId, clientNonce: input.clientNonce, now });
    return { operationId: row.id, commitSecret, expiresAt: now + PREPARE_TTL_MS, gateDisplayName: "", routeDisplayName: "Withdraw request", etaLabel: this.deps.latency.eta("withdraw_permit").label };
  }

  // ---- commit ------------------------------------------------------------

  private rowFor(cap: VerifiedCapability, operationId: string): OperationRow {
    const row = this.deps.store.get(operationId);
    if (!row || row.subject_hash !== hashSubject(cap.subject)) throw new AccessError("operation_not_found");
    return row;
  }

  /**
   * Claim the operation (exactly one caller wins) and return its progress
   * stream. Throws before any event when the claim fails; after that, every
   * outcome — including "unknown" — arrives as a terminal event.
   */
  commit(cap: VerifiedCapability, operationId: string, commitSecret: string): AsyncIterable<AccessProgressEvent> {
    const row = this.rowFor(cap, operationId);
    if (row.state !== "PREPARED") {
      if (this.deps.store.isInFlight(row.state) || isTerminal(row.state)) return this.attach(row.id);
      throw new AccessError("operation_not_prepared");
    }
    const now = this.now();
    if (!this.deps.policy.enabled()) {
      this.deps.store.transition(row.id, "PAUSED", now, { outcomeCode: "access_paused" });
      throw new AccessError("access_paused");
    }
    const claim = this.deps.store.claimCommit(row.id, commitSecret, now);
    if (claim === "secret_invalid") throw new AccessError("commit_secret_invalid");
    if (claim === "expired") throw new AccessError("operation_not_prepared", { reason: "prepare_expired" });
    if (claim === "not_prepared") return this.attach(row.id);
    if (claim === "not_found") throw new AccessError("operation_not_found");

    const live = { events: [] as AccessProgressEvent[], channels: new Set<Channel<AccessProgressEvent>>(), done: false };
    this.streams.set(row.id, live);
    const run = this.dispatch(this.deps.store.get(row.id)!, cap.session.token, now)
      .catch(() => {
        // A journal write failed (e.g. the process is shutting down): the
        // row stays in its in-flight state and restart recovery marks it
        // OUTCOME_UNKNOWN — the truthful answer.
      })
      .finally(() => {
        live.done = true;
        for (const ch of live.channels) ch.close();
        this.inFlight.delete(run);
        setTimeout(() => this.streams.delete(row.id), 60_000).unref();
      });
    this.inFlight.add(run);
    return this.attach(row.id);
  }

  /** Re-attach to a live or finished operation: replay what has happened, then follow. */
  private attach(operationId: string): AsyncIterable<AccessProgressEvent> {
    const live = this.streams.get(operationId);
    const ch = new Channel<AccessProgressEvent>();
    if (live) {
      for (const e of live.events) ch.push(e);
      if (live.done) ch.close();
      else live.channels.add(ch);
      return ch;
    }
    // Finished before this process's memory (restart): synthesize the terminal event from the journal.
    const row = this.deps.store.get(operationId)!;
    const stage = stageOf(row);
    ch.push({ stage, elapsedMs: (row.terminal_at ?? row.created_at) - row.created_at, message: PROGRESS_COPY[stage], ...(row.outcome_detail ? { detail: row.outcome_detail } : {}), terminal: isTerminal(row.state) });
    ch.close();
    return ch;
  }

  private emit(operationId: string, event: AccessProgressEvent): void {
    const live = this.streams.get(operationId);
    if (!live) return;
    live.events.push(event);
    for (const ch of live.channels) ch.push(event);
  }

  private async dispatch(row: OperationRow, token: string, startedAt: number): Promise<void> {
    const kind = row.kind as OperationKind;
    const eta = this.deps.latency.eta(kind);
    const elapsed = () => this.now() - startedAt;
    this.emit(row.id, { stage: "accepted", elapsedMs: elapsed(), etaLowMs: eta.lowMs, etaHighMs: eta.highMs, message: PROGRESS_COPY.accepted, terminal: false });

    this.deps.store.transition(row.id, "DISPATCHING", this.now());
    this.emit(row.id, { stage: "sending", elapsedMs: elapsed(), message: PROGRESS_COPY.sending, terminal: false });

    const call = (): Promise<void> => {
      switch (kind) {
        case "open_gate":
          return this.deps.portal.openDoor(token, row.permit_record_id ?? COMMUTER_RECORD_ID, row.gate_key ?? "");
        case "apply_permit": {
          const p = this.deps.store.payloadOf<{ startTime: string; endTime: string; note: string }>(row)!;
          return this.deps.portal.addPermit(token, p.startTime, p.endTime, p.note);
        }
        case "withdraw_permit":
          return this.deps.portal.deletePermit(token, row.permit_record_id ?? 0);
      }
    };

    // Exactly one attempt. The connector's own logic never retries a mutation.
    const pending = tracedDispatch(call);
    // The request is on the wire once the microtask runs; from here on a failure is "unknown" unless proven never sent.
    await Promise.resolve();
    this.deps.store.transition(row.id, "WAITING_FOR_SCHOOL", this.now());
    this.emit(row.id, { stage: "waiting_for_school", elapsedMs: elapsed(), etaLowMs: eta.lowMs, etaHighMs: eta.highMs, message: PROGRESS_COPY.waiting_for_school, terminal: false });

    const result = await pending;
    const now = this.now();
    let stage: ProgressStage;
    let detail: string | undefined;
    if (result.ok) {
      this.deps.store.transition(row.id, "CONFIRMED", now, { outcomeCode: "confirmed" });
      this.deps.latency.record(kind, true, now - startedAt);
      stage = "confirmed";
    } else if (result.neverSent) {
      this.deps.store.transition(row.id, "NOT_SENT", now, { outcomeCode: "not_sent" });
      stage = "not_sent";
    } else if (isPortalError(result.error)) {
      const e = result.error;
      switch (e.kind) {
        case "operationRejected":
          // The school's own words travel to the student (and the journal) verbatim.
          detail = e.info.kind === "operationRejected" ? e.info.reason : undefined;
          // Shape only (keys and kinds, never values): if the school's words did not
          // come through, this line says where the portal put them.
          if (e.info.kind === "operationRejected") console.warn(`[honey-access] ${row.kind} rejected: reason=${detail ? "yes" : "none"} shape=${e.info.shape ?? "?"}`);
          this.deps.store.transition(row.id, "REJECTED", now, { outcomeCode: "portal_rejected", ...(detail ? { outcomeDetail: detail } : {}), ...(e.info.kind === "operationRejected" && e.info.status !== undefined ? { upstreamStatus: e.info.status } : {}) });
          stage = "rejected";
          break;
        case "sessionExpired":
          // The portal refused the session: it did nothing.
          this.deps.store.transition(row.id, "REJECTED", now, { outcomeCode: "portal_session_expired", upstreamStatus: 401 });
          stage = "rejected";
          break;
        case "timeout":
        case "serverUnavailable":
        case "schemaIncompatible":
        case "networkUnavailable":
        default:
          this.deps.store.transition(row.id, "OUTCOME_UNKNOWN", now, { outcomeCode: e.kind, ...(e.info.kind === "serverUnavailable" && e.info.httpStatus !== undefined ? { upstreamStatus: e.info.httpStatus } : {}) });
          stage = "outcome_unknown";
      }
    } else {
      this.deps.store.transition(row.id, "OUTCOME_UNKNOWN", now, { outcomeCode: "unexpected_error" });
      stage = "outcome_unknown";
    }
    this.emit(row.id, { stage, elapsedMs: elapsed(), message: PROGRESS_COPY[stage], ...(detail ? { detail } : {}), terminal: true });
  }

  status(cap: VerifiedCapability, operationId: string): OperationStatus {
    const row = this.rowFor(cap, operationId);
    if (row.state === "PREPARED" && this.now() - row.prepared_at > PREPARE_TTL_MS) {
      this.deps.store.transition(row.id, "EXPIRED", this.now(), { outcomeCode: "prepare_expired" });
      return this.deps.store.status(this.deps.store.get(row.id)!);
    }
    return this.deps.store.status(row);
  }
}

function stageOf(row: OperationRow): ProgressStage {
  switch (row.state) {
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
