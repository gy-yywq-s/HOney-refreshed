// The motion kit's JS half — ONLY state-explaining motion (review v3
// §5.5.3): the index-staggered entrance style, skeletons, and the live
// clock. Ambient loops, pointer glow, parallax, count-ups and the
// scroll-reveal component are gone. Everything checks
// prefers-reduced-motion and stays transform/opacity-only.

import { useEffect, useLayoutEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";

export function prefersReducedMotion(): boolean {
  return (
    typeof matchMedia !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/** Index-based entrance delay for `.stagger` rows (capped by the CSS). */
export function staggerStyle(index: number): CSSProperties {
  return { "--i": index } as CSSProperties;
}

/** A ticking clock (for live countdowns); pauses under reduced motion at 60s. */
export function useNowTick(intervalMs = 1000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const ms = prefersReducedMotion() ? Math.max(intervalMs, 60_000) : intervalMs;
    const t = setInterval(() => setNow(Date.now()), ms);
    return () => clearInterval(t);
  }, [intervalMs]);
  return now;
}

/** Hairline skeleton rows for loading states (shimmer under the motion kill rule). */
export function Skeleton({ lines = 2 }: { lines?: number }) {
  return (
    <div className="skeleton" role="status" aria-label="Loading">
      {Array.from({ length: lines }, (_, i) => (
        <span key={i} className="skeleton__row" style={{ width: `${88 - i * 14}%` }} />
      ))}
    </div>
  );
}

/**
 * A list that grows and shrinks in front of you rather than jumping (Gary
 * 2026-09-03: show all 和收起都要渐进). The element keeps its own layout —
 * only the transition between the old height and the new one is animated,
 * both measured, so nothing is guessed or hard-coded. Under reduced motion
 * the change is instant.
 */
export function useHeightTransition<T extends HTMLElement>(dep: unknown) {
  const ref = useRef<T>(null);
  const previous = useRef<number | null>(null);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const next = el.scrollHeight;
    const from = previous.current;
    previous.current = next;
    if (from === null || from === next || prefersReducedMotion()) return;
    el.style.overflow = "hidden";
    el.style.height = `${from}px`;
    void el.getBoundingClientRect().height; // commit the start height
    el.style.transition = "height 0.28s cubic-bezier(0.32, 0.72, 0, 1)";
    el.style.height = `${next}px`;
    const done = () => {
      el.style.transition = "";
      el.style.height = "";
      el.style.overflow = "";
      el.removeEventListener("transitionend", done);
    };
    el.addEventListener("transitionend", done);
    const fallback = window.setTimeout(done, 420);
    return () => {
      window.clearTimeout(fallback);
      el.removeEventListener("transitionend", done);
    };
  }, [dep]);
  return ref;
}
