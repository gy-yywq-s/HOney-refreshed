import { useCallback, useEffect, useState } from "react";
import { describeApiError } from "../api/client";

export function useLoadable<T>(load: () => Promise<T>, key: string) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try { setData(await load()); }
    catch (cause) { setError(describeApiError(cause)); }
    finally { setLoading(false); }
    // The caller supplies a semantic key for the request parameters.
  }, [key]);

  useEffect(() => { void refresh(); }, [refresh]);
  return { data, loading, error, refresh, setData };
}
