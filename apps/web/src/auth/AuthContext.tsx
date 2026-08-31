import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import { api, ApiError, describeApiError } from "../api/client";
import type { Me } from "../api/types";

interface AuthContextValue {
  me: Me | null;
  loading: boolean;
  error: string | null;
  refreshMe: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate();
  const [me, setMe] = useState<Me | null>(null);
  const [loading, setLoading] = useState(api.hasSession());
  const [error, setError] = useState<string | null>(null);

  const refreshMe = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setMe(await api.me());
    } catch (err) {
      // A 401 already triggered onSessionLost (redirect); anything else is shown.
      if (!(err instanceof ApiError && err.status === 401)) setError(describeApiError(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    api.onSessionLost = () => {
      setMe(null);
      navigate("/login", { replace: true });
    };
    return () => {
      api.onSessionLost = null;
    };
  }, [navigate]);

  useEffect(() => {
    if (api.hasSession()) void refreshMe();
  }, [refreshMe]);

  const signOut = useCallback(async () => {
    await api.logout();
    setMe(null);
    navigate("/login", { replace: true });
  }, [navigate]);

  const value = useMemo(
    () => ({ me, loading, error, refreshMe, signOut }),
    [me, loading, error, refreshMe, signOut],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
