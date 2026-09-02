// A signed-in way into the school portal (Gary, 2026-09-02: opening School
// Portal must not land on its login page, and staying signed in there is
// not the student's configuration to make). The portal's own login page
// accepts its token in the URL and stores it itself; HOney holds that
// token (about a day's life) and, with the saved school login, can renew
// it silently. The link is prepared BEFORE the tap — a plain href, no
// window.open after an await — so it works in the installed app too,
// where a new tab shares no HOney session.

import { useEffect, useState } from "react";
import { api } from "../api/client";

export const PORTAL_HOME = "https://www.huayaopudong.com/student/notification";
const MARGIN_MS = 5 * 60_000;

export function usePortalEntry(): string {
  const [entry, setEntry] = useState<{ url: string; expiresAt: number } | null>(null);

  useEffect(() => {
    let alive = true;
    let inFlight = false;
    const refresh = async () => {
      if (inFlight) return;
      if (entry && entry.expiresAt - Date.now() > MARGIN_MS) return;
      inFlight = true;
      try {
        const { entry: next } = await api.portalEntrySeamless();
        if (alive && next.status === "ok") setEntry({ url: next.url, expiresAt: next.expiresAt });
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
  }, [entry]);

  return entry && entry.expiresAt - Date.now() > MARGIN_MS ? entry.url : PORTAL_HOME;
}
