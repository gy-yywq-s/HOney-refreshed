// A signed-in way into the school portal (Gary, 2026-09-02: opening School
// Portal must not land on its login page, and staying signed in there is
// not the student's configuration to make). The portal's own login page
// accepts its token in the URL and stores it itself; HOney holds that
// token (about a day's life) and, with the saved school login, can renew
// it silently. The link is prepared BEFORE the tap — a plain href, no
// window.open after an await — so it works in the installed app too,
// where a new tab shares no HOney session.

import { useCallback, useEffect, useState } from "react";
import { api } from "../api/client";
import { portalCredentials } from "./portalCredentials";

const PORTAL_ORIGIN = "https://www.huayaopudong.com";
/** Where a portal link lands when nothing more specific is wanted. */
export const PORTAL_HOME = `${PORTAL_ORIGIN}/student/notification`;
const MARGIN_MS = 5 * 60_000;
/**
 * The hop stores HOney's token in the PORTAL's own localStorage and then goes
 * where the portal decides. A deep page only works while that stored token is
 * still alive — a dead one bounces to the portal's login page, which is
 * exactly what this entry exists to avoid — so the hand-over remembers WHICH
 * token it gave and until when, and deep links are used only inside that
 * window. Outside it, the hop runs again and re-stores a fresh token.
 */
const WARM_KEY = "honey.portal.warmUntil";

function warmUntil(): number {
  try {
    return Number(localStorage.getItem(WARM_KEY) ?? 0) || 0;
  } catch {
    return 0;
  }
}

function warm(): boolean {
  return warmUntil() - Date.now() > MARGIN_MS;
}

function markPortalWarm(expiresAt: number): void {
  try {
    localStorage.setItem(WARM_KEY, String(expiresAt));
  } catch {
    /* the next tap simply takes the login hop again */
  }
}

export interface PortalEntryState {
  /** The signed-in link, or the plain portal address. */
  href: string;
  /** True when HOney cannot enter signed in and this device holds no school
   *  login to renew with: the row asks for it once instead of landing on the
   *  portal's login page (Gary 2026-09-02). */
  needsLogin: boolean;
  /** Ask again (after the login was entered). */
  refresh: () => void;
  /**
   * The link for a particular portal page ("/student/card"). Straight there
   * when this browser has already been handed over once; otherwise the
   * signed-in hop, which the portal itself routes.
   */
  deepHref: (path: string) => string;
  /** Call when a portal link is actually opened. */
  opened: () => void;
}

export function usePortalEntry(): PortalEntryState {
  const [entry, setEntry] = useState<{ url: string; expiresAt: number } | null>(null);
  const [needsLogin, setNeedsLogin] = useState(false);
  const [tick, setTick] = useState(0);
  const refresh = useCallback(() => setTick((t) => t + 1), []);

  useEffect(() => {
    let alive = true;
    let inFlight = false;
    const refresh = async () => {
      if (inFlight) return;
      if (entry && entry.expiresAt - Date.now() > MARGIN_MS) return;
      inFlight = true;
      try {
        const { entry: next } = await api.portalEntrySeamless();
        if (!alive) return;
        if (next.status === "ok") {
          setEntry({ url: next.url, expiresAt: next.expiresAt });
          setNeedsLogin(false);
        } else {
          setNeedsLogin(!portalCredentials.isAuthorized());
        }
      } catch {
        /* the plain portal address stays the fallback */
      } finally {
        inFlight = false;
      }
    };
    void refresh();
    // The token can die while the app sits in the background.
    const onVisible = () => {
      if (document.visibilityState === "visible") void refresh();
    };
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("focus", onVisible);
    return () => {
      alive = false;
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("focus", onVisible);
    };
  }, [entry, tick]);

  const live = entry && entry.expiresAt - Date.now() > MARGIN_MS ? entry : null;
  const href = live ? live.url : PORTAL_HOME;
  return {
    href,
    needsLogin,
    refresh,
    // Straight there while the portal still holds a live token from us;
    // otherwise the hop, which stores one again.
    deepHref: (path: string) => (warm() ? `${PORTAL_ORIGIN}${path}` : href),
    opened: () => {
      if (!warm() && live) markPortalWarm(live.expiresAt);
    },
  };
}
