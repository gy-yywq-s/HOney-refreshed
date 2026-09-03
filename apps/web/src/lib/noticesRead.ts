// Which school notices this device has read. The portal has no per-student
// read flag (its dashboard endpoint returns only a count, never which ones),
// so the fact lives here and is never sent anywhere: nobody at school learns
// what a student opened (Gary 2026-09-03).

import { useSyncExternalStore } from "react";

const KEY = "honey.notices.read";
const listeners = new Set<() => void>();

function read(): string[] {
  try {
    const raw = localStorage.getItem(KEY);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed.filter((v): v is string => typeof v === "string") : [];
  } catch {
    return [];
  }
}

let cache: string[] = read();
let cacheKey = cache.join(",");

function refresh(): void {
  cache = read();
  cacheKey = cache.join(",");
  listeners.forEach((l) => l());
}

export function markNoticeRead(id: string): void {
  const next = read();
  if (next.includes(id)) return;
  next.push(id);
  try {
    // Keep the list bounded: the portal's own list is short and old ids can go.
    localStorage.setItem(KEY, JSON.stringify(next.slice(-200)));
  } catch {
    /* a device that cannot store simply shows everything as new */
  }
  refresh();
}

export function markAllNoticesRead(ids: string[]): void {
  try {
    const merged = Array.from(new Set([...read(), ...ids]));
    localStorage.setItem(KEY, JSON.stringify(merged.slice(-200)));
  } catch {
    /* ignore */
  }
  refresh();
}

/** The ids this device has read (stable identity while unchanged). */
export function useReadNotices(): { has: (id: string) => boolean; key: string } {
  const key = useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => cacheKey,
    () => "",
  );
  return { has: (id: string) => cache.includes(id), key };
}
