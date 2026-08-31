import { useCallback, useEffect, useState } from "react";
import { describeApiError } from "../api/client";

interface UseApiState<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
}

export interface UseApiResult<T> extends UseApiState<T> {
  reload: () => void;
}

/** Minimal data-fetching hook: refetches when `deps` change or `reload()` is called. */
export function useApi<T>(fn: () => Promise<T>, deps: readonly unknown[]): UseApiResult<T> {
  const [state, setState] = useState<UseApiState<T>>({ data: null, error: null, loading: true });
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setState((s) => ({ ...s, loading: true, error: null }));
    fn().then(
      (data) => {
        if (!cancelled) setState({ data, error: null, loading: false });
      },
      (err: unknown) => {
        if (!cancelled) setState((s) => ({ ...s, error: describeApiError(err), loading: false }));
      },
    );
    return () => {
      cancelled = true;
    };
    // `fn` is intentionally excluded: callers pass explicit deps instead.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);

  const reload = useCallback(() => setTick((t) => t + 1), []);
  return { ...state, reload };
}
