// Times on the Access screens are the SCHOOL's wall clock (Asia/Shanghai):
// a permit that says 08:00–22:00 on the portal says the same here, whatever
// the device's zone is set to.

const SCHOOL_TZ = "Asia/Shanghai";

const timeFmt = new Intl.DateTimeFormat("en-GB", { timeZone: SCHOOL_TZ, hour: "2-digit", minute: "2-digit", hour12: false });
const dayFmt = new Intl.DateTimeFormat("en-GB", { timeZone: SCHOOL_TZ, month: "short", day: "numeric" });
const dayKeyFmt = new Intl.DateTimeFormat("en-CA", { timeZone: SCHOOL_TZ, year: "numeric", month: "2-digit", day: "2-digit" });

export function schoolTime(ms: number): string {
  return timeFmt.format(new Date(ms));
}

export function schoolDay(ms: number): string {
  return dayFmt.format(new Date(ms));
}

export function isSchoolToday(ms: number, now: number): boolean {
  return dayKeyFmt.format(new Date(ms)) === dayKeyFmt.format(new Date(now));
}

/** "Today 08:00–22:00" or "3 Sep 08:00 – 4 Sep 06:00". */
export function permitWindow(start: number | null, end: number | null, now: number): string {
  if (start === null || end === null) return "";
  const sameDay = dayKeyFmt.format(new Date(start)) === dayKeyFmt.format(new Date(end));
  const dayLabel = (ms: number) => (isSchoolToday(ms, now) ? "Today" : schoolDay(ms));
  if (sameDay) return `${dayLabel(start)} ${schoolTime(start)}–${schoolTime(end)}`;
  return `${dayLabel(start)} ${schoolTime(start)} – ${dayLabel(end)} ${schoolTime(end)}`;
}

/** "2026-09-03T12:00" for a datetime-local input, in the school's zone. */
export function toLocalInput(ms: number): string {
  const key = dayKeyFmt.format(new Date(ms));
  return `${key}T${schoolTime(ms)}`;
}

/** datetime-local value → the portal's "YYYY-MM-DD HH:mm:ss" (school zone wall time). */
export function fromLocalInput(value: string): string | null {
  const m = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})(?::(\d{2}))?$/.exec(value);
  if (!m) return null;
  return `${m[1]} ${m[2]}:${m[3] ?? "00"}`;
}

export function elapsedLabel(ms: number): string {
  return `${(ms / 1000).toFixed(ms < 10_000 ? 1 : 0)} s`;
}
