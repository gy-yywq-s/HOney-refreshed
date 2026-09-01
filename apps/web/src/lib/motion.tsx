// The motion kit's JS half (work order: motion + "alive" addendum). CSS owns
// the keyframes; this module owns what CSS can't: IntersectionObserver scroll
// reveals, count-up numbers, the pointer-following card highlight, and the
// scroll parallax variable. Everything checks prefers-reduced-motion and
// stays transform/opacity-only; the scroll + pointer handlers are passive
// and rAF-throttled.

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

/**
 * Count-up for stat-strip numbers: animates 0 → value once per mount, then
 * follows later values directly. Skipped entirely under reduced motion.
 */
export function useCountUp(target: number | null, duration = 850): number | null {
  const [value, setValue] = useState<number | null>(target === null ? null : 0);
  const animated = useRef(false);

  useEffect(() => {
    if (target === null) return;
    if (animated.current || prefersReducedMotion() || target === 0) {
      animated.current = true;
      setValue(target);
      return;
    }
    animated.current = true;
    const start = performance.now();
    let raf = requestAnimationFrame(function step(now: number) {
      const p = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      setValue(Math.round(target * eased));
      if (p < 1) raf = requestAnimationFrame(step);
    });
    return () => cancelAnimationFrame(raf);
  }, [target, duration]);

  return value;
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

/**
 * Shell-level ambient handlers: writes --py (scrolled px) for the parallax
 * classes, and --mx/--my on hovered .glow cards for the pointer-following
 * highlight. One passive scroll listener + one delegated pointer listener.
 */
export function useAmbientMotion(): void {
  useEffect(() => {
    if (prefersReducedMotion()) return;
    let raf = 0;
    // Parallax writes transforms directly on the few opted-in nodes; setting
    // a custom property on :root would invalidate style for the whole
    // document every frame (measured as scroll jank under CPU throttling).
    const onScroll = () => {
      if (raf) return;
      raf = requestAnimationFrame(() => {
        const y = window.scrollY;
        for (const el of document.querySelectorAll<HTMLElement>(".parallax-slow")) {
          el.style.transform = `translateY(${(y * -0.05).toFixed(1)}px)`;
        }
        for (const el of document.querySelectorAll<HTMLElement>(".parallax-faint")) {
          el.style.transform = `translateY(${(y * -0.02).toFixed(1)}px)`;
        }
        raf = 0;
      });
    };
    const onPointer = (e: PointerEvent) => {
      const target = e.target instanceof Element ? e.target.closest(".glow") : null;
      if (!(target instanceof HTMLElement)) return;
      const rect = target.getBoundingClientRect();
      target.style.setProperty("--mx", `${(e.clientX - rect.left).toFixed(0)}px`);
      target.style.setProperty("--my", `${(e.clientY - rect.top).toFixed(0)}px`);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    document.addEventListener("pointermove", onPointer, { passive: true });
    onScroll();
    return () => {
      window.removeEventListener("scroll", onScroll);
      document.removeEventListener("pointermove", onPointer);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);
}
