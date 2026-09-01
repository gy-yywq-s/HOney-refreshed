// Pull-to-refresh for the app's scroll owner. Locking body scroll
// (§16.14) removed the browser's native gesture, so the shell provides
// its own: a drag down from the top of [data-scroll-owner] arms a quiet
// indicator; releasing past the threshold clears the SWR cache and emits
// REFRESH_EVENT, which every mounted data hook answers by re-fetching in
// place. Touch-only by design — keyboard/desktop reload still works.

import { useEffect, useRef, useState } from "react";
import { apiCache } from "../lib/useApi";
import { emitRefresh } from "../lib/refresh";

const THRESHOLD = 64; // px of damped pull that commits a refresh
const MAX_PULL = 96;
const MIN_SPIN_MS = 650; // the indicator must read as "something happened"

export function PullToRefresh() {
  const discRef = useRef<HTMLDivElement>(null);
  const [refreshing, setRefreshing] = useState(false);
  const refreshingRef = useRef(false);
  refreshingRef.current = refreshing;

  useEffect(() => {
    const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
    const disc = discRef.current;
    if (!owner || !disc) return;

    let startY = 0;
    let pull = 0;
    let armed = false;

    const paint = () => {
      const shown = Math.min(pull, MAX_PULL);
      disc.style.transform = `translateY(${shown}px) rotate(${shown * 2.4}deg)`;
      disc.style.opacity = String(Math.min(1, shown / THRESHOLD));
    };
    const reset = () => {
      pull = 0;
      armed = false;
      disc.style.transition = "transform 180ms ease, opacity 180ms ease";
      disc.style.transform = "translateY(0)";
      disc.style.opacity = "0";
      window.setTimeout(() => {
        disc.style.transition = "";
      }, 200);
    };

    const onStart = (e: TouchEvent) => {
      if (refreshingRef.current || owner.scrollTop > 0) return;
      const target = e.target as Element | null;
      // Never fight an open dialog or a text-editing surface.
      if (target?.closest(".modal-overlay, textarea, input, select")) return;
      startY = e.touches[0]!.clientY;
      armed = true;
      pull = 0;
    };
    const onMove = (e: TouchEvent) => {
      if (!armed || refreshingRef.current) return;
      if (owner.scrollTop > 0) {
        reset();
        return;
      }
      const dy = e.touches[0]!.clientY - startY;
      pull = dy > 0 ? dy * 0.45 : 0; // damped — the pull should feel weighted
      paint();
    };
    const onEnd = () => {
      if (!armed) return;
      const commit = pull >= THRESHOLD;
      if (!commit) {
        reset();
        return;
      }
      armed = false;
      setRefreshing(true);
      disc.style.transform = `translateY(${THRESHOLD}px)`;
      const started = Date.now();
      apiCache.clear();
      emitRefresh();
      window.setTimeout(() => {
        setRefreshing(false);
        reset();
      }, Math.max(0, MIN_SPIN_MS - (Date.now() - started)));
    };

    owner.addEventListener("touchstart", onStart, { passive: true });
    owner.addEventListener("touchmove", onMove, { passive: true });
    owner.addEventListener("touchend", onEnd, { passive: true });
    owner.addEventListener("touchcancel", onEnd, { passive: true });
    return () => {
      owner.removeEventListener("touchstart", onStart);
      owner.removeEventListener("touchmove", onMove);
      owner.removeEventListener("touchend", onEnd);
      owner.removeEventListener("touchcancel", onEnd);
    };
  }, []);

  return (
    <div className="ptr" aria-hidden={!refreshing}>
      <div
        ref={discRef}
        className={refreshing ? "ptr__disc ptr__disc--spin" : "ptr__disc"}
        role="status"
        aria-label={refreshing ? "Refreshing" : "Pull down to refresh"}
      >
        <svg
          viewBox="0 0 24 24"
          width="16"
          height="16"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          aria-hidden="true"
        >
          <path d="M21 12a9 9 0 1 1-2.64-6.36" />
          <path d="M21 3v6h-6" />
        </svg>
      </div>
    </div>
  );
}
