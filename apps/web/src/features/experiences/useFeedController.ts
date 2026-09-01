// Feed controller (review v3 §12.2: pages compose, controllers own behavior).
// Owns: cursor pagination, scope switching, in-session state + scroll
// restoration (leaving and returning lands the reader where they were —
// §16.14 acceptance 14/15), and the quiet new-posts probe (§9.6C).
//
// Key discipline (code review 2026-09-01, H1): the hook stays MOUNTED when
// FeedPage switches scope in place, so `key` can change without a remount.
// All state is therefore tagged with the key it belongs to (stateKey ref):
// snapshots are always written under the key the items came from, and a key
// change re-seeds items/cursors synchronously before anything else runs —
// no cross-scope items, no cross-scope cursors, no corrupted snapshots.

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
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

/** The scroll owner for feed restoration (the app frame's <main>). */
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
  const [end, setEnd] = useState(restored !== null && restored.nextCursor === null);
  const busy = useRef(false);
  // The key the CURRENT items/cursors belong to. Updated only in the
  // key-switch layout effect below, so snapshot writes can never mislabel.
  const stateKey = useRef(key);
  const itemsRef = useRef(items);
  itemsRef.current = items;

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

  const paramsRef = useRef<FeedParams>({ scope, ...filters });
  paramsRef.current = { scope, ...filters };

  const loadFirst = useCallback(async () => {
    const forKey = stateKey.current;
    setLoading(true);
    setError(null);
    try {
      const page = await api.feedPage(paramsRef.current);
      if (stateKey.current !== forKey) return; // key switched mid-flight
      applyPage(page, "replace");
      setNewAvailable(false);
    } catch (err) {
      if (stateKey.current === forKey) setError(describeApiError(err));
    } finally {
      if (stateKey.current === forKey) setLoading(false);
    }
  }, [applyPage]);

  const loadMore = useCallback(async () => {
    const cursor = cursors.current.next;
    const forKey = stateKey.current;
    if (!cursor || busy.current) return;
    busy.current = true;
    setLoadingMore(true);
    try {
      const page = await api.feedPage({ ...paramsRef.current, cursor });
      if (stateKey.current === forKey) applyPage(page, "append");
    } catch {
      /* quiet — the sentinel retries on the next real intersection change */
    } finally {
      busy.current = false;
      setLoadingMore(false);
    }
  }, [applyPage]);

  /** The banner action: back to the top of a fresh stream. */
  const jumpToNew = useCallback(async () => {
    scroller().set(0);
    await loadFirst();
  }, [loadFirst]);

  const writeSnapshot = useCallback((ofKey: string) => {
    snapshots.set(ofKey, {
      items: itemsRef.current,
      nextCursor: cursors.current.next,
      headCursor: cursors.current.head,
      scrollY: scroller().get(),
    });
  }, []);

  // Key switch WITHOUT remount (in-place scope toggle): capture the outgoing
  // key's state at its still-current scroll offset, then re-seed everything
  // for the incoming key. Layout effect: runs before the passive effects
  // below see the new key.
  useLayoutEffect(() => {
    if (stateKey.current === key) return;
    writeSnapshot(stateKey.current);
    stateKey.current = key;
    busy.current = false;
    setNewAvailable(false);
    setError(null);
    setLoadingMore(false);
    const snap = snapshots.get(key) ?? null;
    if (snap) {
      setItems(snap.items);
      cursors.current = { next: snap.nextCursor, head: snap.headCursor };
      setEnd(snap.nextCursor === null);
      setLoading(false);
      requestAnimationFrame(() => scroller().set(snap.scrollY));
    } else {
      setItems([]);
      cursors.current = { next: null, head: null };
      setEnd(false);
      scroller().set(0);
      void loadFirst();
    }
  }, [key, loadFirst, writeSnapshot]);

  // Mount: restore position or fetch page one. (Key switches are handled
  // by the layout effect above; this runs once per mount.)
  useEffect(() => {
    const snap = snapshots.get(stateKey.current);
    if (snap) {
      // Restore after paint; the list must exist before scrolling to it.
      requestAnimationFrame(() => scroller().set(snap.scrollY));
    } else {
      void loadFirst();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Keep the snapshot current + capture scroll on unmount — always under the
  // key the state actually belongs to.
  useEffect(() => {
    writeSnapshot(stateKey.current);
    const ofKey = stateKey.current;
    return () => writeSnapshot(ofKey);
  }, [items, writeSnapshot]);

  // Quiet new-content probe (§9.6C): poll only while visible; a result shows
  // a banner, never a scroll jump.
  useEffect(() => {
    const tick = async () => {
      const head = cursors.current.head;
      if (!head || document.hidden) return;
      const forKey = stateKey.current;
      try {
        const res = await api.feedUpdates(paramsRef.current.scope, head);
        if (res.newItemsAvailable && stateKey.current === forKey) setNewAvailable(true);
      } catch {
        /* quiet */
      }
    };
    const id = setInterval(() => void tick(), UPDATE_POLL_MS);
    return () => clearInterval(id);
  }, [key]);

  return { items, loading, loadingMore, error, end, loadMore, newAvailable, jumpToNew, refresh: loadFirst };
}

/** Test hook: drop all remembered feed positions (fresh session semantics). */
export function __clearFeedSnapshots(): void {
  snapshots.clear();
}
