// Recent contexts for Find (review §8.1): the last few entity pages the
// student opened, kept on this device only. A convenience, never a signal.
const KEY = "honey.exp.recent";
const MAX = 5;

export interface RecentContext {
  name: string;
  path: string;
}

function read(): RecentContext[] {
  try {
    const raw = localStorage.getItem(KEY);
    const parsed = raw ? (JSON.parse(raw) as RecentContext[]) : [];
    return Array.isArray(parsed) ? parsed.filter((r) => r && r.name && r.path) : [];
  } catch {
    return [];
  }
}

export const recentContexts = {
  list(): RecentContext[] {
    return read();
  },
  remember(ctx: RecentContext): void {
    try {
      const next = [ctx, ...read().filter((r) => r.path !== ctx.path)].slice(0, MAX);
      localStorage.setItem(KEY, JSON.stringify(next));
    } catch {
      /* private mode etc. */
    }
  },
};
