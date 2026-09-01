import { useEffect, useRef } from "react";

// After a "Try again", focus must land on the content that replaced the
// banner (design-is r4): arm before reload, focus once loading settles.
// The landing marks itself `data-landed` while it holds that focus, so the
// ring paints only for a retry landing — never for an ordinary tap inside
// a tabindex=-1 region (r6).
export function useRetryFocus<T extends HTMLElement>(loading: boolean) {
  const ref = useRef<T>(null);
  const armed = useRef(false);
  useEffect(() => {
    if (!loading && armed.current) {
      armed.current = false;
      const el = ref.current;
      if (!el) return;
      el.dataset.landed = "";
      el.addEventListener("blur", () => delete el.dataset.landed, { once: true });
      el.focus({ preventScroll: true });
    }
  }, [loading]);
  return { ref, arm: () => { armed.current = true; } };
}
