import { useCallback, useEffect, useState } from "react";
import { describeApiError } from "../api/client";
import { REFRESH_EVENT } from "./refresh";

// Session-lived SWR cache (Gary, 2026-09-01: switching pages must not
// refetch everything). A cache hit renders instantly with loading=false and
// the request still runs in the background, silently replacing the data;
// a background failure keeps the cached view. Keyed entries only — callers
// without a key keep plain fetch-on-mount behavior.
const cache = new Map<string, unknown>();

export const apiCache = {
  /** Drop every entry whose key starts with `prefix` ("" clears all). */
  invalidate(prefix: string): void {
    for (const key of cache.keys()) if (key.startsWith(prefix)) cache.delete(key);
  },
  clear(): void {
    cache.clear();
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

  useEffect(() => {
    let cancelled = false;
    const hit = key !== undefined && cache.has(key) ? (cache.get(key) as T) : null;
    setState({ data: hit, error: null, loading: hit === null });
    fn().then(
      (data) => {
        if (key !== undefined) cache.set(key, data);
        if (!cancelled) setState({ data, error: null, loading: false });
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

  const reload = useCallback(() => setTick((t) => t + 1), []);

  // Pull-to-refresh: every mounted data hook re-fetches in place. The PTR
  // handler clears the SWR cache first, so this is a true revalidation.
  useEffect(() => {
    const onRefresh = () => setTick((t) => t + 1);
    window.addEventListener(REFRESH_EVENT, onRefresh);
    return () => window.removeEventListener(REFRESH_EVENT, onRefresh);
  }, []);

  return { ...state, reload };
}
