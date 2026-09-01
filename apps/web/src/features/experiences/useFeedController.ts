// Feed controller (review v3 §12.2: pages compose, controllers own behavior).
// Owns: cursor pagination, scope switching, in-session state + scroll
// restoration (leaving and returning lands the reader where they were —
// §16.14 acceptance 14/15), and the quiet new-posts probe (§9.6C).

import { useCallback, useEffect, useRef, useState } from "react";
import { api, describeApiError } from "../../api/client";
import type { FeedPage, FeedParams, FeedScope, PublicExperience } from "../../api/types";

export interface FeedFilters {
  entityKey?: string;
  teacherId?: string;
  courseId?: string;
  roomId?: string;
}

interface FeedSnapshot {
  items: PublicExperience[];
  nextCursor: string | null;
  headCursor: string | null;
  scrollY: number;
}

// Session-lived, module-level: survives route changes, dies with the tab.
const snapshots = new Map<string, FeedSnapshot>();

function keyOf(scope: FeedScope, filters: FeedFilters): string {
  return [scope, filters.entityKey ?? "", filters.teacherId ?? "", filters.courseId ?? "", filters.roomId ?? ""].join("|");
}

/** The scroll owner for feed restoration (window until the app-shell frame owns it). */
function scroller(): { get(): number; set(y: number): void } {
  const el = document.querySelector<HTMLElement>("[data-scroll-owner]");
  if (el) return { get: () => el.scrollTop, set: (y) => el.scrollTo({ top: y }) };
  return { get: () => window.scrollY, set: (y) => window.scrollTo({ top: y }) };
}

const UPDATE_POLL_MS = 60_000;

export function useFeedController(scope: FeedScope, filters: FeedFilters = {}) {
  const key = keyOf(scope, filters);
  const restored = snapshots.get(key) ?? null;

  const [items, setItems] = useState<PublicExperience[]>(restored?.items ?? []);
  const [loading, setLoading] = useState(restored === null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [newAvailable, setNewAvailable] = useState(false);
  const cursors = useRef<{ next: string | null; head: string | null }>({
    next: restored?.nextCursor ?? null,
    head: restored?.headCursor ?? null,
  });
  const exhausted = restored !== null && restored.nextCursor === null;
  const [end, setEnd] = useState(exhausted);
  const busy = useRef(false);

  const snapshot = useCallback(() => {
    snapshots.set(key, {
      items,
      nextCursor: cursors.current.next,
      headCursor: cursors.current.head,
      scrollY: scroller().get(),
    });
  }, [key, items]);

  const applyPage = useCallback((page: FeedPage, mode: "replace" | "append") => {
    setItems((prev) => {
      const base = mode === "replace" ? [] : prev;
      const seen = new Set(base.map((i) => i.id));
      return [...base, ...page.items.filter((i) => !seen.has(i.id))];
    });
    cursors.current.next = page.nextCursor;
    if (page.headCursor) cursors.current.head = page.headCursor;
    setEnd(page.nextCursor === null);
  }, []);

  const loadFirst = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params: FeedParams = { scope, ...filters };
      applyPage(await api.feedPage(params), "replace");
      setNewAvailable(false);
    } catch (err) {
      setError(describeApiError(err));
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, applyPage]);

  const loadMore = useCallback(async () => {
    const cursor = cursors.current.next;
    if (!cursor || busy.current) return;
    busy.current = true;
    setLoadingMore(true);
    try {
      applyPage(await api.feedPage({ scope, ...filters, cursor }), "append");
    } catch {
      /* quiet — the sentinel retries when it re-enters the viewport */
    } finally {
      busy.current = false;
      setLoadingMore(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, applyPage]);

  /** The banner action: back to the top of a fresh stream. */
  const jumpToNew = useCallback(async () => {
    scroller().set(0);
    await loadFirst();
  }, [loadFirst]);

  // Mount: restore position or fetch page one.
  useEffect(() => {
    const snap = snapshots.get(key);
    if (snap) {
      // Restore after paint; the list must exist before scrolling to it.
      requestAnimationFrame(() => scroller().set(snap.scrollY));
    } else {
      void loadFirst();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  // Keep the snapshot current + capture scroll on unmount.
  useEffect(() => {
    snapshot();
    return snapshot;
  }, [snapshot]);

  // Quiet new-content probe (§9.6C): poll only while visible; a result shows
  // a banner, never a scroll jump.
  useEffect(() => {
    const tick = async () => {
      const head = cursors.current.head;
      if (!head || document.hidden) return;
      try {
        const res = await api.feedUpdates(scope, head);
        if (res.newItemsAvailable) setNewAvailable(true);
      } catch {
        /* quiet */
      }
    };
    const id = setInterval(() => void tick(), UPDATE_POLL_MS);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return { items, loading, loadingMore, error, end, loadMore, newAvailable, jumpToNew, refresh: loadFirst };
}

/** Test hook: drop all remembered feed positions (fresh session semantics). */
export function __clearFeedSnapshots(): void {
  snapshots.clear();
}
