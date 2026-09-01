import { useEffect, useRef } from "react";

// After a "Try again", focus must land on the content that replaced the
// banner (design-is r4): arm before reload, focus once loading settles.
export function useRetryFocus<T extends HTMLElement>(loading: boolean) {
  const ref = useRef<T>(null);
  const armed = useRef(false);
  useEffect(() => {
    if (!loading && armed.current) {
      armed.current = false;
      ref.current?.focus();
    }
  }, [loading]);
  return { ref, arm: () => { armed.current = true; } };
}
