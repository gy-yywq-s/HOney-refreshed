import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { PropsWithChildren } from "react";
import type { LoginInput, Me } from "@honey/shared/api";
import { api, describeApiError } from "../api/client";

interface AuthValue {
  me: Me | null;
  loading: boolean;
  error: string | null;
  fixtureMode: boolean;
  login(input: LoginInput): Promise<Me>;
  grantConsent(value: boolean): Promise<void>;
  refresh(): Promise<void>;
  logout(): Promise<void>;
}

const AuthContext = createContext<AuthValue | null>(null);

export function AuthProvider({ children }: PropsWithChildren) {
  const [me, setMe] = useState<Me | null>(null);
  const [loading, setLoading] = useState(api.hasSession());
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try { setMe(await api.me()); }
    catch (cause) { setMe(null); setError(describeApiError(cause)); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => {
    api.onSessionLost = () => setMe(null);
    if (api.hasSession()) void refresh();
    return () => { api.onSessionLost = null; };
  }, [refresh]);

  const login = useCallback(async (input: LoginInput) => {
    setLoading(true);
    setError(null);
    try {
      await api.login(input);
      const current = await api.me();
      setMe(current);
      return current;
    } catch (cause) {
      const message = describeApiError(cause);
      setError(message);
      throw new Error(message);
    } finally { setLoading(false); }
  }, []);

  const grantConsent = useCallback(async (value: boolean) => {
    await api.setConsent(value);
    await refresh();
  }, [refresh]);

  const logout = useCallback(async () => {
    await api.logout();
    setMe(null);
  }, []);

  const value = useMemo<AuthValue>(() => ({ me, loading, error, fixtureMode: api.fixtureMode, login, grantConsent, refresh, logout }), [me, loading, error, login, grantConsent, refresh, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used within AuthProvider");
  return value;
}
