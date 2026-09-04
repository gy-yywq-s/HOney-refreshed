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
export const PORTAL_HOME = `${PORTAL_ORIGIN}/student/notification`;
const MARGIN_MS = 5 * 60_000;
/**
 * The portal's login page takes the token, stores it in its own localStorage
 * and then goes where IT decides (its notice board for a student); a deep page
 * carrying the token bounces to that login page, because only the login page
 * reads the query. So the student is never asked to navigate: HOney opens the
 * hop, KEEPS the window it opened, and sends that same window on to the page
 * they asked for once the token is stored — navigating a window you opened is
 * allowed cross-origin (reading it is not). If the tab is slower than this,
 * it is still signed in and simply lands on the portal's own page.
 */
const HOP_SETTLE_MS = 2500;

/**
 * Open a portal page from a tap. `href` is the signed-in hop (the anchor's own
 * href, so a blocked pop-up still works); `path` is where the student meant to
 * go.
 */
export function openPortalPage(href: string, path: string, event?: { preventDefault: () => void }): void {
  const win = window.open(href, "_blank");
  if (!win) return; // the anchor's href takes over
  event?.preventDefault();
  window.setTimeout(() => {
    try {
      win.location.href = `${PORTAL_ORIGIN}${path}`;
    } catch {
      /* the window is gone or refuses: it is signed in either way */
    }
  }, HOP_SETTLE_MS);
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

  return {
    href: entry && entry.expiresAt - Date.now() > MARGIN_MS ? entry.url : PORTAL_HOME,
    needsLogin,
    refresh,
  };
}
