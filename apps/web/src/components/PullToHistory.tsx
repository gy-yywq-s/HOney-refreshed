// Pull up for History (phones, 2026-09-02): with the day canvas at the end
// of its scroll, a deliberate upward drag lifts a small "History" mark
// above the nav; releasing past the threshold opens History. Guards
// against accidents: the owner must already be at its end when the touch
// starts and stay there, the drag must travel far (damped 110px ≈ 240px of
// finger) and last longer than a flick, and the mark shows the exact
// release point before anything happens. Touch-only; desktop keeps its
// History button.

import { useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { t } from "../lib/i18n";

const SHOW_AT = 24;
const OPEN_AT = 110; // damped px
const MAX_LIFT = 128;
const MIN_MS = 220; // a flick is faster than this
const DAMPING = 0.45;

export function PullToHistory() {
  const markRef = useRef<HTMLDivElement>(null);
  const labelRef = useRef<HTMLSpanElement>(null);
  const navigate = useNavigate();

  useEffect(() => {
    const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
    const mark = markRef.current;
    const label = labelRef.current;
    if (!owner || !mark || !label) return;

    let startY = 0;
    let startT = 0;
    let pull = 0;
    let armed = false;
    const atEnd = () => owner.scrollTop >= owner.scrollHeight - owner.clientHeight - 1;

    const paint = () => {
      const lift = Math.min(pull, MAX_LIFT);
      mark.style.transform = `translateY(${-lift}px)`;
      mark.style.opacity = String(Math.max(0, Math.min(1, (pull - SHOW_AT) / 40)));
      if (pull >= OPEN_AT) mark.dataset.ready = "";
      else delete mark.dataset.ready;
      label.textContent = pull >= OPEN_AT ? t("Release to open History") : t("Pull up for History");
    };
    const reset = () => {
      pull = 0;
      armed = false;
      mark.style.transition = "transform 180ms ease, opacity 180ms ease";
      mark.style.transform = "translateY(0)";
      mark.style.opacity = "0";
      delete mark.dataset.ready;
      window.setTimeout(() => {
        mark.style.transition = "";
      }, 200);
    };

    const onStart = (e: TouchEvent) => {
      if (!atEnd()) return;
      const target = e.target as Element | null;
      if (target?.closest(".modal-overlay, textarea, input, select")) return;
      startY = e.touches[0]!.clientY;
      startT = Date.now();
      armed = true;
      pull = 0;
    };
    const onMove = (e: TouchEvent) => {
      if (!armed) return;
      if (!atEnd()) {
        reset();
        return;
      }
      const dy = startY - e.touches[0]!.clientY;
      pull = dy > 0 ? dy * DAMPING : 0;
      paint();
    };
    const onEnd = () => {
      if (!armed) return;
      const deliberate = pull >= OPEN_AT && Date.now() - startT >= MIN_MS;
      reset();
      if (deliberate) navigate("/history");
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
  }, [navigate]);

  return (
    <div ref={markRef} className="pullup" aria-hidden="true">
      <span className="pullup__mark">
        <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M12 19V5M5 12l7-7 7 7" />
        </svg>
        <span ref={labelRef}>Pull up for History</span>
      </span>
    </div>
  );
}
