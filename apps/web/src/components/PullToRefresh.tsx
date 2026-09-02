// Pull-to-refresh for the app's scroll owner. Locking body scroll
// (§16.14) removed the browser's native gesture, so the shell provides
// its own: a drag down from the top of [data-scroll-owner] arms a quiet
// indicator; releasing past the first threshold clears the SWR cache and
// emits REFRESH_EVENT, which every mounted data hook answers by
// re-fetching in place. Pulled further (second stage, 2026-09-02), the
// release syncs with the school portal instead — only on a screen that
// registered a sync handler. Touch-only by design — keyboard/desktop
// reload still works and the desktop keeps its buttons.

import { useEffect, useRef, useState } from "react";
import { apiCache } from "../lib/useApi";
import { emitRefresh, emitSync, syncAvailable } from "../lib/refresh";

const REFRESH_AT = 64; // px of damped pull that commits a refresh
const SYNC_AT = 132; // px of damped pull that commits a school sync
const MAX_PULL = 156;
const MIN_SPIN_MS = 650; // the indicator must read as "something happened"

type Stage = "idle" | "pull" | "refresh" | "sync";

function labelFor(stage: Stage, syncable: boolean): string {
  switch (stage) {
    case "pull":
      return "Pull to refresh";
    case "refresh":
      return syncable ? "Release to refresh · pull further to sync" : "Release to refresh";
    case "sync":
      return "Release to sync with school";
    default:
      return "";
  }
}

export function PullToRefresh() {
  const groupRef = useRef<HTMLDivElement>(null);
  const labelRef = useRef<HTMLSpanElement>(null);
  const [busy, setBusy] = useState<"" | "refresh" | "sync">("");
  const busyRef = useRef(busy);
  busyRef.current = busy;

  useEffect(() => {
    const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
    const group = groupRef.current;
    const label = labelRef.current;
    if (!owner || !group || !label) return;

    let startY = 0;
    let pull = 0;
    let armed = false;
    let syncable = false;

    const stageFor = (px: number): Stage =>
      px >= SYNC_AT && syncable ? "sync" : px >= REFRESH_AT ? "refresh" : px > 12 ? "pull" : "idle";

    const paint = () => {
      const shown = Math.min(pull, MAX_PULL);
      const stage = stageFor(pull);
      group.style.transform = `translateY(${shown}px)`;
      group.style.opacity = String(Math.min(1, shown / REFRESH_AT));
      group.dataset.stage = stage;
      group.style.setProperty("--ptr-spin", `${shown * 2.4}deg`);
      label.textContent = labelFor(stage, syncable);
    };
    const reset = () => {
      pull = 0;
      armed = false;
      group.style.transition = "transform 180ms ease, opacity 180ms ease";
      group.style.transform = "translateY(0)";
      group.style.opacity = "0";
      group.dataset.stage = "idle";
      window.setTimeout(() => {
        group.style.transition = "";
        label.textContent = "";
      }, 200);
    };

    const onStart = (e: TouchEvent) => {
      if (busyRef.current || owner.scrollTop > 0) return;
      const target = e.target as Element | null;
      // Never fight an open dialog or a text-editing surface.
      if (target?.closest(".modal-overlay, textarea, input, select")) return;
      startY = e.touches[0]!.clientY;
      armed = true;
      pull = 0;
      syncable = syncAvailable();
    };
    const onMove = (e: TouchEvent) => {
      if (!armed || busyRef.current) return;
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
      const stage = stageFor(pull);
      if (stage !== "refresh" && stage !== "sync") {
        reset();
        return;
      }
      armed = false;
      setBusy(stage);
      group.style.transform = `translateY(${REFRESH_AT}px)`;
      group.dataset.stage = stage;
      label.textContent = stage === "sync" ? "Syncing with school…" : "Refreshing…";
      const started = Date.now();
      if (stage === "sync") {
        emitSync();
      } else {
        apiCache.clear();
        emitRefresh();
      }
      window.setTimeout(() => {
        setBusy("");
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
    <div className="ptr" aria-hidden={!busy}>
      <div ref={groupRef} className="ptr__group" data-stage="idle">
        <div
          className={busy ? "ptr__disc ptr__disc--spin" : "ptr__disc"}
          role="status"
          aria-label={busy === "sync" ? "Syncing with school" : busy ? "Refreshing" : undefined}
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
        <span ref={labelRef} className="ptr__label caption" />
      </div>
    </div>
  );
}
