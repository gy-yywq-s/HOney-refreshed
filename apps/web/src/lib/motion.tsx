// The motion kit's JS half — ONLY state-explaining motion (review v3
// §5.5.3): the index-staggered entrance style, skeletons, and the live
// clock. Ambient loops, pointer glow, parallax, count-ups and the
// scroll-reveal component are gone. Everything checks
// prefers-reduced-motion and stays transform/opacity-only.

import { useEffect, useState } from "react";
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
