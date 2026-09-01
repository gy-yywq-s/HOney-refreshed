// /experiences/<kind>/:id — intentional lookup (review v3 §9.11): a compact
// header, one sentence of context, the raw chronological stream via the same
// cursor feed the main stream uses, and a share action when eligible. No
// scores, no summaries, no ranking. Course is first-class (§9.10) — course
// retrospectives compose directly. Scroll model: FRAMED_SCROLL.

import { useEffect, useRef } from "react";
import { Link, useParams } from "react-router-dom";
import { ExperiencePost } from "../../features/experiences/ExperiencePost";
import { useFeedController, type FeedFilters } from "../../features/experiences/useFeedController";
import { Skeleton } from "../../lib/motion";
import { useNames } from "./shared";

export type EntityPageKind = "teacher" | "course" | "room" | "dish";

const KIND_TITLE: Record<EntityPageKind, string> = {
  teacher: "Teacher",
  course: "Course",
  room: "Place",
  dish: "Dish",
};

/** One quiet sentence of context per kind (§15.5) + the partiality reminder. */
const KIND_INTRO: Record<EntityPageKind, (name: string) => string> = {
  teacher: (n) => `What students have experienced in classes with ${n}.`,
  course: () => "Experiences of this course across lessons and teachers.",
  room: () => "What students have experienced in this place.",
  dish: () => "What students actually thought of it.",
};

export function ExperienceEntityPage({ kind }: { kind: EntityPageKind }) {
  const { id = "" } = useParams();
  const { names } = useNames();

  const entityKey = `${kind}:${id}`;
  const filters: FeedFilters = {};
  if (kind === "teacher") filters.teacherId = id;
  else if (kind === "room") filters.roomId = id;
  else if (kind === "course") filters.courseId = id;
  else filters.entityKey = entityKey;

  // Entity pages read the school-wide stream, narrowed to this entity.
  const feed = useFeedController("school", filters);

  const sentinel = useRef<HTMLDivElement>(null);
  // Depend on the STABLE loadMore only (review H2): a per-render dependency
  // would rebuild the observer every render, and each rebuild's initial
  // callback re-fires on a still-visible sentinel — a hot retry loop when a
  // page fetch keeps failing.
  const loadMore = feed.loadMore;
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

  const name =
    (kind === "teacher" && (names.teacher.get(id) ?? names.entity.get(entityKey))) ||
    (kind === "room" && (names.room.get(id) ?? names.entity.get(entityKey))) ||
    (kind === "course" && (names.course.get(id) ?? names.entity.get(entityKey))) ||
    (kind === "dish" && names.entity.get(entityKey)) ||
    KIND_TITLE[kind];

  return (
    <div className="stack">
      <header className="page-head">
        <div>
          <div className="overline">{KIND_TITLE[kind]}</div>
          <h1 className="page-title" style={{ marginBottom: 0 }}>
            {name}
          </h1>
        </div>
        <Link
          className="btn btn--primary"
          to={`/experiences/compose?entityKey=${encodeURIComponent(entityKey)}`}
        >
          Share your experience
        </Link>
      </header>

      <p className="muted entity-intro">
        {KIND_INTRO[kind](name)} No single Experience is the whole picture.
      </p>

      {feed.loading ? (
        <Skeleton lines={4} />
      ) : feed.error ? (
        <div role="alert" className="banner banner--danger">{feed.error}</div>
      ) : feed.items.length === 0 ? (
        <p className="empty">No experiences here yet — yours could be the first.</p>
      ) : (
        <div className="feed-stream">
          {feed.items.map((exp) => (
            <ExperiencePost key={exp.id} exp={exp} />
          ))}
        </div>
      )}
      <div ref={sentinel} aria-hidden="true" />
      {feed.loadingMore && <div className="feed-append muted">…</div>}
    </div>
  );
}
