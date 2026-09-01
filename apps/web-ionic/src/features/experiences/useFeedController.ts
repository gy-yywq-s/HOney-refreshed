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
//
// Snapshot discipline (Gary bug report 2026-09-01, "feed shows nothing"):
// only a state that completed a successful first load may be snapshotted.
// The old code snapshotted the initial items=[] render; leaving the page
// before page one arrived persisted { items: [], nextCursor: null }, and
// every return restored an empty, end=true feed without ever refetching.
// hasLoaded gates every snapshot write, and empty-item snapshots are
// treated as absent on restore (a truly empty feed refetches — cheap and
// self-healing).

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { api, describeApiError } from "../../api/client";
import { REFRESH_EVENT } from "../../lib/refresh";
import { useScrollOwner } from "../../components/IonicRoutePage";
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

const UPDATE_POLL_MS = 60_000;

export function useFeedController(scope: FeedScope, filters: FeedFilters = {}) {
  const scrollOwner = useScrollOwner();
  const key = keyOf(scope, filters);
  const stored = snapshots.get(key) ?? null;
  const restored = stored && stored.items.length > 0 ? stored : null;

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
  // True once the CURRENT key's state completed a successful first load
  // (page one applied, or restored from a loaded snapshot). Snapshots are
  // written only while true.
  const hasLoaded = useRef(restored !== null);
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
    hasLoaded.current = true;
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
    scrollOwner.scrollTo(0);
    await loadFirst();
  }, [loadFirst, scrollOwner]);

  const writeSnapshot = useCallback((ofKey: string) => {
    if (!hasLoaded.current) return; // never persist a never-loaded state
    snapshots.set(ofKey, {
      items: itemsRef.current,
      nextCursor: cursors.current.next,
      headCursor: cursors.current.head,
      scrollY: scrollOwner.getY(),
    });
  }, [scrollOwner]);

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
    const raw = snapshots.get(key) ?? null;
    const snap = raw && raw.items.length > 0 ? raw : null;
    hasLoaded.current = snap !== null;
    if (snap) {
      setItems(snap.items);
      cursors.current = { next: snap.nextCursor, head: snap.headCursor };
      setEnd(snap.nextCursor === null);
      setLoading(false);
      requestAnimationFrame(() => scrollOwner.scrollTo(snap.scrollY));
    } else {
      setItems([]);
      cursors.current = { next: null, head: null };
      setEnd(false);
      scrollOwner.scrollTo(0);
      void loadFirst();
    }
  }, [key, loadFirst, scrollOwner, writeSnapshot]);

  // Mount: restore position or fetch page one. (Key switches are handled
  // by the layout effect above; this runs once per mount.)
  useEffect(() => {
    const snap = snapshots.get(stateKey.current);
    if (snap && snap.items.length > 0) {
      // Restore after paint; the list must exist before scrolling to it.
      requestAnimationFrame(() => scrollOwner.scrollTo(snap.scrollY));
    } else {
      void loadFirst();
    }
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

  // App-level refresh (pull-to-refresh emits REFRESH_EVENT): reload page
  // one for the current key. The banner state resets — a refresh IS the jump.
  useEffect(() => {
    const onRefresh = () => {
      setNewAvailable(false);
      void loadFirst();
    };
    window.addEventListener(REFRESH_EVENT, onRefresh);
    return () => window.removeEventListener(REFRESH_EVENT, onRefresh);
  }, [loadFirst]);

  return { items, loading, loadingMore, error, end, loadMore, newAvailable, jumpToNew, refresh: loadFirst };
}

/** Test hook: drop all remembered feed positions (fresh session semantics). */
export function __clearFeedSnapshots(): void {
  snapshots.clear();
}
