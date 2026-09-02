// Pull-to-refresh for the app's scroll owner. Locking body scroll
// (§16.14) removed the browser's native gesture, so the shell provides
// its own. Two stages (Gary, 2026-09-02): release past the first re-reads
// HOney (clears the SWR cache, emits REFRESH_EVENT); pulled far further
// AND held, the release syncs with the school portal — only on a screen
// that registered a sync handler. Stage rules live in lib/pullStages.ts.
//
// Motion (2026-09-02, after the Ionic reference build): the content is
// never moved by hand while the finger is down on iOS. iOS already
// rubber-bands the scroll region; the pill simply READS that displacement
// (negative scrollTop, the way Ionic's native refresher does) so there is
// exactly one motion on screen. Elsewhere — no rubber band — a damped
// finger drag moves the content itself. Both engines hold the content a
// little way down while the work runs, then ease it home. Touch-only by
// design — keyboard/desktop reload still works and the desktop keeps its
// buttons.

import { useEffect, useRef, useState } from "react";
import { apiCache } from "../lib/useApi";
import { emitRefresh, emitSync, syncAvailable } from "../lib/refresh";
import { t } from "../lib/i18n";
import { commitFor, HOLD_MS, REFRESH_AT, stageFor, syncAtFor, type PullStage } from "../lib/pullStages";

const MAX_PULL = 180; // drag engine: the content will not follow past this
const DRAG_DAMPING = 0.45;
const HOLD_PX = 56; // where the content rests while the work runs
const MIN_SPIN_MS = 650; // the indicator must read as "something happened"
const EASE = "cubic-bezier(0.32, 0.72, 0, 1)";

/** iOS/iPadOS WebKit: the scroll region rubber-bands and reports it. */
function rubberBands(): boolean {
  try {
    return navigator.maxTouchPoints > 0 && CSS.supports("background: -webkit-named-image(apple-pay-logo-black)");
  } catch {
    return false;
  }
}

function labelFor(stage: PullStage): string {
  switch (stage) {
    case "pull":
      return t("Pull to refresh");
    case "refresh":
      return t("Release to refresh");
    case "further":
      return t("Keep pulling to sync with school");
    case "hold":
      return t("Hold to sync…");
    case "sync":
      return t("Release to sync with school");
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
    const native = rubberBands();
    const content = (): HTMLElement | null => owner.querySelector<HTMLElement>(":scope > .view");

    let startY = 0;
    let px = 0; // real displacement of the content
    let armed = false;
    let syncable = false;
    let holdSince = 0; // when the pull first reached the sync distance
    let holdTimer = 0;
    let stage: PullStage = "idle";
    const thresholds = () => ({ refreshAt: REFRESH_AT, syncAt: syncAtFor(owner.clientHeight), holdMs: HOLD_MS });

    const paint = () => {
      const th = thresholds();
      const heldMs = holdSince ? Date.now() - holdSince : 0;
      const next = stageFor(px, syncable, heldMs, th);
      if (next === "hold" || next === "sync") {
        if (!holdSince) holdSince = Date.now();
      } else {
        holdSince = 0;
      }
      stage = next;
      group.style.opacity = String(Math.min(1, px / th.refreshAt));
      group.dataset.stage = stage;
      group.style.setProperty("--ptr-spin", `${Math.min(px, MAX_PULL) * 2.4}deg`);
      group.style.setProperty("--ptr-hold", stage === "hold" ? String(Math.min(1, heldMs / th.holdMs)) : stage === "sync" ? "1" : "0");
      label.textContent = labelFor(stage);
      // The hold fill runs on a clock, not on finger movement: keep painting
      // while the finger rests at the sync distance.
      window.clearTimeout(holdTimer);
      if (stage === "hold") holdTimer = window.setTimeout(paint, 40);
    };

    const settle = () => {
      const view = content();
      if (!view) return;
      view.style.transition = `transform 0.36s ${EASE}`;
      view.style.transform = "";
      window.setTimeout(() => {
        view.style.transition = "";
      }, 400);
    };
    const hide = () => {
      group.style.transition = "opacity 180ms ease";
      group.style.opacity = "0";
      group.dataset.stage = "idle";
      group.style.setProperty("--ptr-hold", "0");
      window.setTimeout(() => {
        group.style.transition = "";
        label.textContent = "";
      }, 200);
    };
    const reset = () => {
      window.clearTimeout(holdTimer);
      px = 0;
      armed = false;
      holdSince = 0;
      stage = "idle";
      hide();
      if (!native) settle();
    };

    const commit = (what: "refresh" | "sync") => {
      window.clearTimeout(holdTimer);
      armed = false;
      holdSince = 0;
      setBusy(what);
      group.dataset.stage = what;
      group.style.opacity = "1";
      group.style.setProperty("--ptr-hold", "0");
      label.textContent = what === "sync" ? t("Syncing with school…") : t("Refreshing…");
      // Hold the content down under the pill while the work runs — on iOS
      // this catches the rubber band's snap-back so the content does not
      // bounce over the indicator (Ionic does the same).
      const view = content();
      if (view) {
        view.style.transition = `transform 0.3s ${EASE}`;
        view.style.transform = `translateY(${HOLD_PX}px)`;
      }
      const started = Date.now();
      if (what === "sync") {
        emitSync();
      } else {
        apiCache.clear();
        emitRefresh();
      }
      window.setTimeout(
        () => {
          setBusy("");
          px = 0;
          stage = "idle";
          hide();
          settle();
        },
        Math.max(0, MIN_SPIN_MS - (Date.now() - started)),
      );
    };

    const onStart = (e: TouchEvent) => {
      if (busyRef.current || owner.scrollTop > 0) return;
      const target = e.target as Element | null;
      // Never fight an open dialog or a text-editing surface.
      if (target?.closest(".modal-overlay, textarea, input, select")) return;
      startY = e.touches[0]!.clientY;
      armed = true;
      px = 0;
      holdSince = 0;
      syncable = syncAvailable();
      if (!native) {
        const view = content();
        if (view) view.style.transition = "none";
      }
    };
    // iOS engine: the rubber band is the pull; read it.
    const onScroll = () => {
      if (!armed || busyRef.current) return;
      const top = owner.scrollTop;
      if (top > 0) {
        reset();
        return;
      }
      px = -top;
      paint();
    };
    // Drag engine: a damped finger drag moves the content.
    const onMove = (e: TouchEvent) => {
      if (native || !armed || busyRef.current) return;
      if (owner.scrollTop > 0) {
        reset();
        return;
      }
      const dy = e.touches[0]!.clientY - startY;
      px = dy > 0 ? Math.min(MAX_PULL, dy * DRAG_DAMPING) : 0;
      const view = content();
      if (view) view.style.transform = px > 0 ? `translateY(${px}px)` : "";
      paint();
    };
    const onEnd = () => {
      if (!armed) return;
      const what = commitFor(stage);
      if (!what) {
        reset();
        return;
      }
      commit(what);
    };

    owner.addEventListener("touchstart", onStart, { passive: true });
    owner.addEventListener("touchmove", onMove, { passive: true });
    owner.addEventListener("touchend", onEnd, { passive: true });
    owner.addEventListener("touchcancel", onEnd, { passive: true });
    owner.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.clearTimeout(holdTimer);
      owner.removeEventListener("touchstart", onStart);
      owner.removeEventListener("touchmove", onMove);
      owner.removeEventListener("touchend", onEnd);
      owner.removeEventListener("touchcancel", onEnd);
      owner.removeEventListener("scroll", onScroll);
    };
  }, []);

  return (
    <div className="ptr" aria-hidden={!busy}>
      <div
        ref={groupRef}
        className="ptr__pill"
        data-stage="idle"
        role="status"
        aria-label={busy === "sync" ? "Syncing with school" : busy ? "Refreshing" : undefined}
      >
        <svg
          className={busy ? "ptr__icon ptr__icon--spin" : "ptr__icon"}
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
        <span ref={labelRef} className="ptr__label" />
      </div>
    </div>
  );
}
