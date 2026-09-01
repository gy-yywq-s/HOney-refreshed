export function formatTime(value: number): string {
  return new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false }).format(value);
}

export function formatDay(value: Date): string {
  return new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long" }).format(value);
}

export function formatShortDay(value: Date): string {
  return new Intl.DateTimeFormat("en-GB", { weekday: "short", day: "numeric", month: "short" }).format(value);
}

export function relativeBucket(dayBucket: number | null): string {
  if (dayBucket === null) return "";
  const today = Math.floor(Date.now() / 86_400_000);
  const delta = today - dayBucket;
  if (delta <= 0) return "today";
  if (delta === 1) return "yesterday";
  if (delta < 7) return `${delta} days ago`;
  if (delta < 14) return "last week";
  return "earlier this term";
}
