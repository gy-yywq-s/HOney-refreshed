// Infinite-scroll sentinel shared by every stream surface (r2: the same
// observer block lived in FeedPage and EntityPage).
//
// Depends on the STABLE loadMore only (review H2): a per-render dependency
// would rebuild the observer every render, and each rebuild's initial
// callback re-fires on a still-visible sentinel — a hot retry loop when a
// page fetch keeps failing.

import { useEffect, useRef } from "react";

export function useLoadMoreSentinel(loadMore: () => Promise<void>) {
  const sentinel = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = sentinel.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) void loadMore();
      },
      { rootMargin: "600px 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, [loadMore]);
  return sentinel;
}
