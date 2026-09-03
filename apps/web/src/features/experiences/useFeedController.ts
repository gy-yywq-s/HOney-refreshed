// Feed controller (review v3 §12.2: pages compose, controllers own behavior).
// Owns: cursor pagination, scope switching, in-session state + scroll
// restoration (leaving and returning lands the reader where they were —
// §16.14 acceptance 14/15), and the quiet new-posts probe (§9.6C).
//
// v2: the stream comes from the identity-free Community process. "Your
// classes" sends the viewer's canonical exposure ids (from Core) with the
// request; Community never learns who asks. Names are joined client-side.
//
// Key discipline (code review 2026-09-01, H1): the hook stays MOUNTED when
// FeedPage switches scope in place, so `key` can change without a remount.
// All state is therefore tagged with the key it belongs to (stateKey ref).
// Snapshot discipline (Gary bug report 2026-09-01): only a state that
// completed a successful first load may be snapshotted.

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import type { ExposureScope, FeedPageV2, FeedRequestV2, PublicExperienceV2 } from "@honey/shared/community-v2";
import { describeApiError } from "../../api/client";
import { community } from "../../api/community";
import { communitySession } from "../../lib/community-v2/publish-client";
import { nameExperiences } from "../../lib/entityNames";
import { REFRESH_EVENT } from "../../lib/refresh";

export type FeedScope = "my_classes" | "school";

export interface FeedFilters {
  entityKey?: string;
  teacherId?: string;
  courseId?: string;
  roomId?: string;
}

interface FeedSnapshot {
  items: PublicExperienceV2[];
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

async function exposure(scope: FeedScope): Promise<ExposureScope | undefined> {
  if (scope === "school") return undefined;
  const s = await communitySession();
  return { teachers: s.scope.teachers, courses: s.scope.courses, lessons: s.scope.lessons };
}

async function fetchPage(req: FeedRequestV2): Promise<FeedPageV2> {
  const exp = await exposure(req.scope);
  const page = await community.feed({ ...req, ...(exp ? { exposure: exp } : {}) });
  return { ...page, items: await nameExperiences(page.items) };
}

export function useFeedController(scope: FeedScope, filters: FeedFilters = {}) {
  const key = keyOf(scope, filters);
  const stored = snapshots.get(key) ?? null;
  const restored = stored && stored.items.length > 0 ? stored : null;

  const [items, setItems] = useState<PublicExperienceV2[]>(restored?.items ?? []);
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
  const hasLoaded = useRef(restored !== null);
  const stateKey = useRef(key);
  const itemsRef = useRef(items);
  itemsRef.current = items;

  const applyPage = useCallback((page: FeedPageV2, mode: "replace" | "append") => {
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

  const paramsRef = useRef<FeedRequestV2>({ scope, ...filters });
  paramsRef.current = { scope, ...filters };

  const loadFirst = useCallback(async () => {
    const forKey = stateKey.current;
    setLoading(true);
    setError(null);
    try {
      const page = await fetchPage(paramsRef.current);
      if (stateKey.current !== forKey) return;
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
      const page = await fetchPage({ ...paramsRef.current, cursor });
      if (stateKey.current === forKey) applyPage(page, "append");
    } catch {
      /* quiet — the sentinel retries on the next real intersection change */
    } finally {
      busy.current = false;
      setLoadingMore(false);
    }
  }, [applyPage]);

  const jumpToNew = useCallback(async () => {
    scroller().set(0);
    await loadFirst();
  }, [loadFirst]);

  const writeSnapshot = useCallback((ofKey: string) => {
    if (!hasLoaded.current) return;
    snapshots.set(ofKey, { items: itemsRef.current, nextCursor: cursors.current.next, headCursor: cursors.current.head, scrollY: scroller().get() });
  }, []);

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
      requestAnimationFrame(() => scroller().set(snap.scrollY));
    } else {
      setItems([]);
      cursors.current = { next: null, head: null };
      setEnd(false);
      scroller().set(0);
      void loadFirst();
    }
  }, [key, loadFirst, writeSnapshot]);

  useEffect(() => {
    const snap = snapshots.get(stateKey.current);
    if (snap && snap.items.length > 0) {
      requestAnimationFrame(() => scroller().set(snap.scrollY));
    } else {
      void loadFirst();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
        const s = paramsRef.current.scope;
        const exp = await exposure(s);
        const res = await community.feedUpdates({ scope: s, head, ...(exp ? { exposure: exp } : {}) });
        if (res.newItemsAvailable && stateKey.current === forKey) setNewAvailable(true);
      } catch {
        /* quiet */
      }
    };
    const id = setInterval(() => void tick(), UPDATE_POLL_MS);
    return () => clearInterval(id);
  }, [key]);

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
