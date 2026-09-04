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
/** The portal's login hop stores its token in ITS OWN localStorage and then
 *  redirects where IT decides (a student lands on the notice board). Once that
 *  has happened in this browser, a deep link works on its own — so remember it
 *  and send the student straight to the page they asked for (Gary 2026-09-04). */
const WARM_KEY = "honey.portal.warm";

function warm(): boolean {
  try {
    return localStorage.getItem(WARM_KEY) === "1";
  } catch {
    return false;
  }
}

export function markPortalWarm(): void {
  try {
    localStorage.setItem(WARM_KEY, "1");
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

  const href = entry && entry.expiresAt - Date.now() > MARGIN_MS ? entry.url : PORTAL_HOME;
  return {
    href,
    needsLogin,
    refresh,
    deepHref: (path: string) => (warm() ? `${PORTAL_ORIGIN}${path}` : href),
    opened: markPortalWarm,
  };
}
