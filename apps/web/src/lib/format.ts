// Small date/time helpers. "iso date" below means a local-timezone YYYY-MM-DD.

export function toIsoDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function todayIsoDate(): string {
  return toIsoDate(new Date());
}

/** Parses YYYY-MM-DD as a local date (Date.parse would read it as UTC). */
export function parseIsoDate(iso: string): Date {
  const [y, m, d] = iso.split("-").map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
}

export function shiftIsoDate(iso: string, days: number): string {
  const d = parseIsoDate(iso);
  d.setDate(d.getDate() + days);
  return toIsoDate(d);
}

export function formatTime(timestamp: number | string): string {
  return new Date(timestamp).toLocaleTimeString("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

export function formatDayHeading(iso: string): string {
  return parseIsoDate(iso).toLocaleDateString("en-GB", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export function formatShortDate(timestamp: number | string): string {
  return new Date(timestamp).toLocaleDateString("en-GB", {
    weekday: "short",
    day: "numeric",
    month: "short",
  });
}

export function monthLabel(timestamp: number | string): string {
  return new Date(timestamp).toLocaleDateString("en-GB", { month: "long", year: "numeric" });
}

export function timeAgo(timestamp: string): string {
  const min = Math.round((Date.now() - new Date(timestamp).getTime()) / 60000);
  if (min < 1) return "just now";
  if (min < 60) return `${min} min ago`;
  const h = Math.round(min / 60);
  if (h < 24) return `${h} h ago`;
  return new Date(timestamp).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

export function isStale(timestamp: string | null, maxMinutes = 60): boolean {
  if (!timestamp) return true;
  return Date.now() - new Date(timestamp).getTime() > maxMinutes * 60000;
}

/**
 * Renders a coarse day bucket (days since epoch — the only public time
 * granularity Experiences has; exact timestamps never exist publicly).
 */
export function formatDayBucket(day: number): string {
  return new Date(day * 86_400_000).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

/** Coarse (date-only) rendering of an epoch-ms timestamp. */
export function formatCoarseDate(ms: number): string {
  return new Date(ms).toLocaleDateString("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

/** "3 h 12 min" style remaining-time label for cooldown countdowns. */
export function formatRemaining(ms: number): string {
  const totalMin = Math.max(1, Math.ceil(ms / 60_000));
  const h = Math.floor(totalMin / 60);
  const min = totalMin % 60;
  if (h === 0) return `${min} min`;
  return min === 0 ? `${h} h` : `${h} h ${min} min`;
}
