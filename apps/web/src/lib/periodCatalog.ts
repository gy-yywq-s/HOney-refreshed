// The school day, defined ONCE (timetable addendum v1.1 §18): P1–P6 and the
// two named breaks. The Day canvas positions by these minutes; the Week
// matrix uses them as rows. Neither view may carry its own copy.

export interface TimelineBand {
  id: string;
  /** Minutes from midnight, local school time. */
  start: number;
  end: number;
  kind: "period" | "break";
  /** Period number, or the break's label. */
  period?: number;
  label?: string;
}

export const BANDS: TimelineBand[] = [
  { id: "p1", start: 9 * 60, end: 10 * 60 + 30, kind: "period", period: 1 },
  { id: "p2", start: 10 * 60 + 30, end: 12 * 60, kind: "period", period: 2 },
  { id: "lunch", start: 12 * 60, end: 13 * 60 + 30, kind: "break", label: "Lunch Break" },
  { id: "p3", start: 13 * 60 + 30, end: 15 * 60, kind: "period", period: 3 },
  { id: "p4", start: 15 * 60, end: 16 * 60 + 30, kind: "period", period: 4 },
  { id: "p5", start: 16 * 60 + 30, end: 18 * 60, kind: "period", period: 5 },
  { id: "dinner", start: 18 * 60, end: 18 * 60 + 30, kind: "break", label: "Dinner Break" },
  { id: "p6", start: 18 * 60 + 30, end: 20 * 60, kind: "period", period: 6 },
];

export const PERIODS = BANDS.filter((b) => b.kind === "period");

export function minuteOfDay(timestamp: number): number {
  const d = new Date(timestamp);
  return d.getHours() * 60 + d.getMinutes();
}

export function overlapsSlot(slot: TimelineBand, start: number, end: number): boolean {
  return start < slot.end && end > slot.start;
}

export function periodLabelFor(start: number, end: number): string | null {
  const slot = PERIODS.find((s) => overlapsSlot(s, start, end));
  return slot ? `P${slot.period}` : null;
}

/** "P3" → the band; the lesson's period is the FIRST slot it overlaps. */
export function periodOf(startMinute: number, endMinute: number): TimelineBand | null {
  return PERIODS.find((s) => overlapsSlot(s, startMinute, endMinute)) ?? null;
}

/** Minutes → "13:30". */
export function minuteLabel(minute: number): string {
  const h = Math.floor(minute / 60);
  const m = minute % 60;
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}`;
}
