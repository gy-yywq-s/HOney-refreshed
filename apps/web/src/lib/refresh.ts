// App-level refresh bus. The shell owns the viewport (body scroll is
// locked, §16.14), which removed the browser's native pull-to-refresh —
// so the app provides its own: PullToRefresh emits this event, and every
// data owner (useApi, useFeedController) re-fetches in place.
//
// The pull has a second stage (Gary, 2026-09-02): pulled further, it
// syncs with the school portal instead of only re-reading HOney. A screen
// that can sync registers a handler with useSyncHandler; while one is
// mounted the gesture offers the second stage.

import { useEffect, useRef } from "react";

export const REFRESH_EVENT = "honey:refresh";
export const SYNC_EVENT = "honey:sync";

export function emitRefresh(): void {
  window.dispatchEvent(new Event(REFRESH_EVENT));
}

let syncHandlers = 0;

export function emitSync(): void {
  window.dispatchEvent(new Event(SYNC_EVENT));
}

/** True while a mounted screen can answer the sync stage. */
export function syncAvailable(): boolean {
  return syncHandlers > 0;
}

/** Answer the pull's sync stage with this screen's own sync action. */
export function useSyncHandler(handler: () => void): void {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    syncHandlers += 1;
    const on = () => ref.current();
    window.addEventListener(SYNC_EVENT, on);
    return () => {
      syncHandlers -= 1;
      window.removeEventListener(SYNC_EVENT, on);
    };
  }, []);
}
