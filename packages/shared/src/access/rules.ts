// Access domain rules shared by the Web, the Access Service and (mirrored)
// iOS `AccessRules.swift`: which permit can open a gate, what a permit row
// says, and the quick-apply defaults. Pure and testable.
//
// The consumed-permit rule (Gary, 2026-09-02): a permit already used to open
// a gate — from HOney OR the official site — must not show as openable.
// Approval (`status`) and consumption (`flag`) are different facts; both are
// checked, and the list is re-read before any physical authority is granted.

import type { DoorOptionWire, ExitPermitWire } from "../portal/contract.js";

export type PermitState = "pending" | "approved" | "rejected" | "opened" | "unknown";

export interface Permit {
  recordId: number;
  state: PermitState;
  statusName: string;
  reason: string;
  flag: number;
  /** Epoch ms in the school's zone, null when the portal string is unparsable. */
  start: number | null;
  end: number | null;
  rawStart: string;
  rawEnd: string;
  createdAt: number | null;
}

export interface Door {
  key: string;
  displayName: string;
}

export type AccessRouteKind = "day_student" | "exit_permit";

/** Commuter (day-student) direct-open sentinel used as record_id. */
export const COMMUTER_RECORD_ID = -2;

const SCHOOL_TZ_OFFSET_MS = 8 * 3600 * 1000; // Asia/Shanghai, no DST

/** "2026-08-31 08:00:00" in the school's local zone → epoch ms. */
export function parsePortalTime(text: string | null | undefined): number | null {
  if (!text) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/.exec(text.trim());
  if (!m) return null;
  const [y, mo, d, h, mi, s] = m.slice(1).map(Number) as [number, number, number, number, number, number];
  return Date.UTC(y, mo - 1, d, h, mi, s) - SCHOOL_TZ_OFFSET_MS;
}

export function formatPortalTime(ms: number): string {
  const d = new Date(ms + SCHOOL_TZ_OFFSET_MS);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())}`;
}

export function permitFromWire(w: ExitPermitWire): Permit {
  const states: Record<number, PermitState> = { 0: "pending", 1: "approved", 2: "rejected", 3: "opened" };
  return {
    recordId: w.record_id,
    state: states[w.status] ?? "unknown",
    statusName: w.status_name ?? "",
    reason: (w.note ?? "").trim(),
    flag: w.flag ?? 0,
    start: parsePortalTime(w.start_time),
    end: parsePortalTime(w.end_time),
    rawStart: w.start_time ?? "",
    rawEnd: w.end_time ?? "",
    createdAt: parsePortalTime(w.create_time),
  };
}

export function doorFromWire(d: DoorOptionWire): Door {
  return { key: d.key, displayName: d.value };
}

/** Already used at a gate (door flag set) or marked opened by the portal. */
export function isConsumed(p: Permit): boolean {
  return p.state === "opened" || p.flag !== 0;
}

/** Approved, unused, and inside its time window right now. */
export function isOpenable(p: Permit, now: number): boolean {
  if (p.state !== "approved" || isConsumed(p) || p.start === null || p.end === null) return false;
  return p.start <= now && now <= p.end;
}

export function isExpired(p: Permit, now: number): boolean {
  return p.end !== null && p.end < now;
}

/** "Exit" when the note is empty (the portal's default reason is 出门). */
export function displayReason(p: Permit): string {
  return p.reason || "Exit";
}

export type PermitTone = "ok" | "muted" | "warning" | "danger";

export function permitTone(p: Permit, now: number): PermitTone {
  if (isConsumed(p)) return "muted";
  switch (p.state) {
    case "approved":
      return isExpired(p, now) ? "muted" : "ok";
    case "pending":
      return "warning";
    case "rejected":
      return "danger";
    default:
      return "muted";
  }
}

/** The chip text: the portal's own status name when it has one, consumed winning over a stale "approved". */
export function displayStatus(p: Permit): string {
  if (isConsumed(p)) return p.state === "opened" && p.statusName ? p.statusName : "Used";
  if (p.statusName) return p.statusName;
  return { pending: "Pending", approved: "Approved", rejected: "Rejected", opened: "Opened", unknown: "Unknown" }[p.state];
}

/** Openable permits, most recent first. */
export function openablePermits(permits: Permit[], now: number): Permit[] {
  return permits.filter((p) => isOpenable(p, now)).sort((a, b) => (b.start ?? 0) - (a.start ?? 0));
}

/** Newest first for the list. */
export function sortedForList(permits: Permit[]): Permit[] {
  return [...permits].sort((a, b) => (b.start ?? b.createdAt ?? 0) - (a.start ?? a.createdAt ?? 0));
}

/** The apply-permit quick default: now → +2 h, reason 出门. */
export const DEFAULT_PERMIT_REASON = "出门";
export function quickPermitDraft(now: number): { start: number; end: number; reason: string } {
  return { start: now, end: now + 2 * 3600 * 1000, reason: DEFAULT_PERMIT_REASON };
}
