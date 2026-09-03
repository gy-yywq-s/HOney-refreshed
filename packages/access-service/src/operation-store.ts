// The operation journal (spec §18–19): every physical action is a row whose
// state moves PREPARED → COMMITTED → DISPATCHING → WAITING_FOR_SCHOOL →
// CONFIRMED | REJECTED | OUTCOME_UNKNOWN, or PREPARED → EXPIRED | PAUSED |
// NOT_SENT. The commit secret is stored only as a hash; the subject only as
// a hash; the token never. A row that was dispatching when the process died
// is OUTCOME_UNKNOWN on restart — it is never re-sent.

import { createHash, randomBytes } from "node:crypto";
import type { DatabaseSync } from "node:sqlite";
import type { OperationState, OperationStatus } from "@honey/shared/access";

export type OperationKind = "open_gate" | "apply_permit" | "withdraw_permit";

export interface OperationRow {
  id: string;
  subject_hash: string;
  kind: OperationKind;
  gate_key: string | null;
  permit_record_id: number | null;
  state: OperationState;
  created_at: number;
  prepared_at: number;
  committed_at: number | null;
  dispatch_started_at: number | null;
  upstream_headers_at: number | null;
  upstream_finished_at: number | null;
  terminal_at: number | null;
  outcome_code: string | null;
  outcome_detail: string | null;
  upstream_status: number | null;
  service_version: string;
}

export const PREPARE_TTL_MS = 60_000;
const TERMINAL: ReadonlySet<OperationState> = new Set(["EXPIRED", "PAUSED", "NOT_SENT", "CONFIRMED", "REJECTED", "OUTCOME_UNKNOWN"]);
const IN_FLIGHT: ReadonlySet<OperationState> = new Set(["COMMITTED", "DISPATCHING", "WAITING_FOR_SCHOOL"]);

export function isTerminal(state: OperationState): boolean {
  return TERMINAL.has(state);
}

export function hashSecret(secret: string): string {
  return createHash("sha256").update(secret).digest("base64url");
}

export function hashSubject(subject: string): string {
  return createHash("sha256").update("honey/access/subject\n" + subject).digest("base64url").slice(0, 32);
}

export class OperationStore {
  constructor(
    private readonly db: DatabaseSync,
    private readonly serviceVersion: string,
  ) {}

  /** Crash recovery: anything in flight at startup has an unknown outcome and is never re-sent. */
  recoverAfterRestart(now: number): number {
    const r = this.db
      .prepare(
        `UPDATE access_operations SET state = 'OUTCOME_UNKNOWN', outcome_code = 'service_restarted', terminal_at = ?, updated_at = ?
         WHERE state IN ('COMMITTED', 'DISPATCHING', 'WAITING_FOR_SCHOOL')`,
      )
      .run(now, now);
    this.db.prepare(`UPDATE access_operations SET state = 'EXPIRED', terminal_at = ?, updated_at = ? WHERE state = 'PREPARED'`).run(now, now);
    return Number(r.changes);
  }

  /** A subject may have at most one non-terminal operation. */
  activeFor(subjectHash: string): OperationRow | null {
    return (this.db.prepare(`SELECT * FROM access_operations WHERE subject_hash = ? AND state IN ('PREPARED','COMMITTED','DISPATCHING','WAITING_FOR_SCHOOL') LIMIT 1`).get(subjectHash) as OperationRow | undefined) ?? null;
  }

  prepare(input: { subjectHash: string; kind: OperationKind; gateKey?: string; permitRecordId?: number; clientNonce?: string; payload?: unknown; now: number }): { row: OperationRow; commitSecret: string } {
    const id = "op_" + randomBytes(12).toString("base64url");
    const commitSecret = randomBytes(24).toString("base64url");
    this.db
      .prepare(
        `INSERT INTO access_operations (id, subject_hash, kind, gate_key, permit_record_id, state, commit_hash, client_nonce, payload, created_at, prepared_at, service_version, updated_at)
         VALUES (?, ?, ?, ?, ?, 'PREPARED', ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        id,
        input.subjectHash,
        input.kind,
        input.gateKey ?? null,
        input.permitRecordId ?? null,
        hashSecret(commitSecret),
        input.clientNonce ?? null,
        input.payload === undefined ? null : JSON.stringify(input.payload),
        input.now,
        input.now,
        this.serviceVersion,
        input.now,
      );
    return { row: this.get(id)!, commitSecret };
  }

  payloadOf<T>(row: OperationRow): T | null {
    const raw = (this.db.prepare("SELECT payload FROM access_operations WHERE id = ?").get(row.id) as { payload: string | null }).payload;
    return raw ? (JSON.parse(raw) as T) : null;
  }

  get(id: string): OperationRow | null {
    return (this.db.prepare("SELECT * FROM access_operations WHERE id = ?").get(id) as OperationRow | undefined) ?? null;
  }

  /**
   * Atomic claim: PREPARED → COMMITTED only if the secret matches and the
   * prepare has not expired. Two concurrent commits: exactly one wins.
   */
  claimCommit(id: string, commitSecret: string, now: number): "claimed" | "secret_invalid" | "expired" | "not_prepared" | "not_found" {
    const row = this.get(id);
    if (!row) return "not_found";
    if (row.state !== "PREPARED") return "not_prepared";
    if (hashSecret(commitSecret) !== (this.db.prepare("SELECT commit_hash FROM access_operations WHERE id = ?").get(id) as { commit_hash: string }).commit_hash) return "secret_invalid";
    if (now - row.prepared_at > PREPARE_TTL_MS) {
      this.transition(id, "EXPIRED", now, { outcomeCode: "prepare_expired" });
      return "expired";
    }
    const r = this.db.prepare(`UPDATE access_operations SET state = 'COMMITTED', committed_at = ?, updated_at = ? WHERE id = ? AND state = 'PREPARED'`).run(now, now, id);
    return Number(r.changes) === 1 ? "claimed" : "not_prepared";
  }

  transition(id: string, state: OperationState, now: number, extra: { outcomeCode?: string; outcomeDetail?: string; upstreamStatus?: number } = {}): void {
    const stamp =
      state === "DISPATCHING" ? "dispatch_started_at = ?," : state === "WAITING_FOR_SCHOOL" ? "upstream_headers_at = ?," : isTerminal(state) ? "terminal_at = ?, upstream_finished_at = COALESCE(upstream_finished_at, ?)," : "";
    const stampArgs = state === "DISPATCHING" || state === "WAITING_FOR_SCHOOL" ? [now] : isTerminal(state) ? [now, now] : [];
    this.db
      .prepare(
        `UPDATE access_operations SET state = ?, ${stamp} outcome_code = COALESCE(?, outcome_code), outcome_detail = COALESCE(?, outcome_detail),
         upstream_status = COALESCE(?, upstream_status), upstream_status_class = COALESCE(?, upstream_status_class), updated_at = ? WHERE id = ?`,
      )
      .run(state, ...stampArgs, extra.outcomeCode ?? null, extra.outcomeDetail?.slice(0, 200) ?? null, extra.upstreamStatus ?? null, extra.upstreamStatus ? `${Math.floor(extra.upstreamStatus / 100)}xx` : null, now, id);
  }

  status(row: OperationRow): OperationStatus {
    return { operationId: row.id, state: row.state, outcomeCode: row.outcome_code, createdAt: row.created_at, terminalAt: row.terminal_at };
  }

  countActive(): number {
    return (this.db.prepare(`SELECT COUNT(*) AS n FROM access_operations WHERE state IN ('PREPARED','COMMITTED','DISPATCHING','WAITING_FOR_SCHOOL')`).get() as { n: number }).n;
  }

  countUnknownSince(since: number): number {
    return (this.db.prepare(`SELECT COUNT(*) AS n FROM access_operations WHERE state = 'OUTCOME_UNKNOWN' AND terminal_at >= ?`).get(since) as { n: number }).n;
  }

  /** Journal rows for the Dash/transcript: no subject, no secret. */
  recent(limit: number): Omit<OperationRow, "subject_hash">[] {
    return (this.db.prepare(`SELECT id, kind, gate_key, permit_record_id, state, created_at, prepared_at, committed_at, dispatch_started_at, upstream_headers_at, upstream_finished_at, terminal_at, outcome_code, outcome_detail, upstream_status, service_version FROM access_operations ORDER BY created_at DESC LIMIT ?`).all(limit) as Omit<OperationRow, "subject_hash">[]);
  }

  isInFlight(state: OperationState): boolean {
    return IN_FLIGHT.has(state);
  }
}
