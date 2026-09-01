// /experiences/<kind>/:id — intentional lookup (review v3 §9.11): a compact
// header, one sentence of context, the raw chronological stream via the same
// cursor feed the main stream uses, and a share action when eligible. No
// scores, no summaries, no ranking. Course is first-class (§9.10) — course
// retrospectives compose directly. Scroll model: FRAMED_SCROLL.

import { Link, useParams } from "react-router-dom";
import { ExperiencePost } from "../../features/experiences/ExperiencePost";
import { useFeedController, type FeedFilters } from "../../features/experiences/useFeedController";
import { Skeleton } from "../../lib/motion";
import { api } from "../../api/client";
import { useApi } from "../../lib/useApi";
import { useLoadMoreSentinel } from "../../features/experiences/useLoadMoreSentinel";
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
  dish: () => "What students thought of it.",
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
  const sentinel = useLoadMoreSentinel(feed.loadMore);

  // Delisted entries (deduped rooms, placeholders) stay reachable by URL
  // but must not offer a composer that the server will refuse (r2).
  const registry = useApi(() => api.entities(), [], "entities");
  const listed = !registry.data || registry.data.entities.some((e) => e.entity_key === entityKey);

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
        {listed && (
          <Link
            className="btn btn--primary"
            to={`/experiences/compose?entityKey=${encodeURIComponent(entityKey)}`}
          >
            Share your experience
          </Link>
        )}
      </header>
      {!listed && <p className="muted entity-intro">This entry is no longer listed.</p>}

      <p className="muted entity-intro">
        {KIND_INTRO[kind](name)} No single Experience is the whole picture.
      </p>

      {feed.loading ? (
        <Skeleton lines={4} />
      ) : feed.error ? (
        <div role="alert" className="banner banner--danger">
          <span>{feed.error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => void feed.refresh()}>
            Try again
          </button>
        </div>
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
