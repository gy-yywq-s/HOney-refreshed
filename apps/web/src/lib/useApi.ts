import { useCallback, useEffect, useRef, useState } from "react";
import { describeApiError } from "../api/client";
import { REFRESH_EVENT } from "./refresh";

// Session-lived SWR cache (Gary, 2026-09-01: switching pages must not
// refetch everything). A cache hit renders instantly with loading=false and
// the request still runs in the background, silently replacing the data;
// a background failure keeps the cached view. Keyed entries only — callers
// without a key keep plain fetch-on-mount behavior.
const cache = new Map<string, unknown>();
const CACHE_MAX = 40; // per-session SWR cap (r9 relay): oldest entries drop first
function remember(key: string, value: unknown): void {
  if (cache.has(key)) cache.delete(key);
  cache.set(key, value);
  while (cache.size > CACHE_MAX) {
    const oldest = cache.keys().next().value;
    if (oldest === undefined) break;
    cache.delete(oldest);
  }
}
// In-flight requests by key: two hooks mounting in the same tick share one
// network call instead of racing (design-is r6: compose fired /api/entities
// twice, concurrently).
const inflight = new Map<string, Promise<unknown>>();

export const apiCache = {
  /** Drop every entry whose key starts with `prefix` ("" clears all). */
  invalidate(prefix: string): void {
    for (const key of cache.keys()) if (key.startsWith(prefix)) cache.delete(key);
    for (const key of inflight.keys()) if (key.startsWith(prefix)) inflight.delete(key);
  },
  clear(): void {
    cache.clear();
    inflight.clear(); // a refresh must never be served a pre-refresh promise
  },
};

interface UseApiState<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
}

export interface UseApiResult<T> extends UseApiState<T> {
  reload: () => void;
}

/** Data hook: refetches when `deps` change or `reload()` is called; with a
 *  `key`, serves the cached value immediately and revalidates in background. */
export function useApi<T>(
  fn: () => Promise<T>,
  deps: readonly unknown[],
  key?: string,
): UseApiResult<T> {
  const initial = key !== undefined && cache.has(key) ? (cache.get(key) as T) : null;
  const [state, setState] = useState<UseApiState<T>>({
    data: initial,
    error: null,
    loading: initial === null,
  });
  const [tick, setTick] = useState(0);
  // A reload() is a forced miss: the next effect run shows loading=true even
  // when the key is cached, so a retry landing has a flag to arm on (r9).
  const forced = useRef(false);

  useEffect(() => {
    let cancelled = false;
    const hit = key !== undefined && cache.has(key) && !forced.current ? (cache.get(key) as T) : null;
    forced.current = false;
    setState({ data: hit, error: null, loading: hit === null });
    const run = (): Promise<T> => {
      if (key === undefined) return fn();
      const pending = inflight.get(key) as Promise<T> | undefined;
      if (pending) return pending;
      const p = fn().finally(() => {
        if (inflight.get(key) === p) inflight.delete(key);
      });
      inflight.set(key, p);
      return p;
    };
    run().then(
      (data) => {
        // A superseded request (refresh, key change) must never write the
        // cache after the one that replaced it (r8): only the live effect's
        // request may store its body.
        if (cancelled) return;
        if (key !== undefined) remember(key, data);
        setState({ data, error: null, loading: false });
      },
      (err: unknown) => {
        if (!cancelled)
          setState((s) => ({
            ...s,
            // With a cached view on screen, a failed revalidation stays silent.
            error: hit === null ? describeApiError(err) : s.error,
            loading: false,
          }));
      },
    );
    return () => {
      cancelled = true;
    };
    // `fn`/`key` are intentionally excluded: callers pass explicit deps.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  const reload = useCallback(() => {
    if (key !== undefined) inflight.delete(key); // a reload always re-fetches
    forced.current = true;
    setTick((t) => t + 1);
  }, [key]);

  // Pull-to-refresh: every mounted data hook re-fetches in place. The PTR
  // handler clears the SWR cache first, so this is a true revalidation.
  useEffect(() => {
    const onRefresh = () => setTick((t) => t + 1);
    window.addEventListener(REFRESH_EVENT, onRefresh);
    return () => window.removeEventListener(REFRESH_EVENT, onRefresh);
  }, []);

  return { ...state, reload };
}
