// The motion kit's JS half — web-lab round 2 keeps ONLY state-explaining
// motion (review v3 §5.5.3): entrance reveals on navigation, skeletons, and
// the live clock. Ambient loops, pointer glow, parallax and count-ups are
// gone. Everything checks prefers-reduced-motion and stays
// transform/opacity-only.

import { createElement, useEffect, useRef, useState } from "react";
import type { CSSProperties, ReactElement, ReactNode } from "react";

export function prefersReducedMotion(): boolean {
  return (
    typeof matchMedia !== "undefined" && matchMedia("(prefers-reduced-motion: reduce)").matches
  );
}

/** Style helper for the stagger index custom property. */
export function staggerStyle(index: number): CSSProperties {
  return { "--i": index } as CSSProperties;
}

type RevealTag = "div" | "section" | "article" | "li" | "header";

interface RevealProps {
  as?: RevealTag;
  /** Stagger index (delay = index * 40ms, capped at 8 by the CSS). */
  index?: number;
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
  "aria-label"?: string;
}

/**
 * Scroll-linked reveal: renders hidden (opacity 0, translateY) and eases in
 * when it enters the viewport. Re-arms naturally on navigation because views
 * remount per route.
 */
export function Reveal({
  as = "div",
  index = 0,
  className,
  style,
  children,
  ...rest
}: RevealProps): ReactElement {
  const ref = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (prefersReducedMotion() || typeof IntersectionObserver === "undefined") {
      el.classList.add("is-in");
      return;
    }
    // Already on screen? Ease in on the next frame (still staggered).
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        }
      },
      { rootMargin: "0px 0px -6% 0px", threshold: 0.06 },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return createElement(
    as,
    {
      ref,
      className: className ? `reveal ${className}` : "reveal",
      style: { ...style, ...staggerStyle(index) },
      ...rest,
    },
    children,
  );
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
