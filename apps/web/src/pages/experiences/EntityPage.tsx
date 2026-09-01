// /experiences/<kind>/:id — one entity's feed. The URL carries the id part of
// the entity_key (e.g. /experiences/teacher/t42 ⇔ entity_key "teacher:t42").
// Teacher/room pages use the filter-time context params so lesson experiences
// surface here too; dish pages filter by entity_key. Course pages are a
// context filter only (courses are not standalone entities).

import { useState } from "react";
import type { CSSProperties } from "react";
import { Link, useParams } from "react-router-dom";
import { api } from "../../api/client";
import type { ExperiencesFeedParams } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { ExperienceCard, useNames } from "./shared";

export type EntityPageKind = "teacher" | "course" | "room" | "dish";

const KIND_FALLBACK_TITLE: Record<EntityPageKind, string> = {
  teacher: "Teacher",
  course: "Course",
  room: "Place",
  dish: "Dish",
};

export function ExperienceEntityPage({ kind }: { kind: EntityPageKind }) {
  const { id = "" } = useParams();
  const [sort, setSort] = useState<"newest" | "oldest">("newest");
  const { names } = useNames();

  const entityKey = `${kind}:${id}`;
  const params: ExperiencesFeedParams = { sort, limit: 100 };
  if (kind === "teacher") params.teacherId = id;
  else if (kind === "room") params.roomId = id;
  else if (kind === "course") params.courseId = id;
  else params.entityKey = entityKey;

  const feed = useApi(() => api.experiencesFeed(params), [kind, id, sort]);

  const name =
    (kind === "teacher" && (names.teacher.get(id) ?? names.entity.get(entityKey))) ||
    (kind === "room" && (names.room.get(id) ?? names.entity.get(entityKey))) ||
    (kind === "course" && names.course.get(id)) ||
    (kind === "dish" && names.entity.get(entityKey)) ||
    KIND_FALLBACK_TITLE[kind];

  const experiences = feed.data?.experiences ?? null;
  const canCompose = kind !== "course"; // courses are reviewed via their lessons

  return (
    <div className="stack">
      <header className="page-head">
        <div>
          <div className="overline">{KIND_FALLBACK_TITLE[kind]}</div>
          <h1 className="page-title" style={{ marginBottom: 0 }}>
            {name}
          </h1>
        </div>
        {canCompose ? (
          <Link
            className="btn btn--primary"
            to={`/experiences/compose?entityKey=${encodeURIComponent(entityKey)}`}
          >
            Share an experience
          </Link>
        ) : (
          <Link className="btn btn--primary" to="/history?select=1">
            Review one of these lessons
          </Link>
        )}
      </header>

      <div
        className="sort-toggle"
        role="group"
        aria-label="Sort order"
        style={{ "--n": 2, "--active": sort === "newest" ? 0 : 1 } as CSSProperties}
      >
        {(["newest", "oldest"] as const).map((s) => (
          <button
            key={s}
            type="button"
            className={sort === s ? "sort-toggle__btn sort-toggle__btn--on" : "sort-toggle__btn"}
            aria-pressed={sort === s}
            onClick={() => setSort(s)}
          >
            {s === "newest" ? "Newest" : "Oldest"}
          </button>
        ))}
      </div>

      {feed.loading ? (
        <p className="muted">Loading…</p>
      ) : feed.error ? (
        <div role="alert" className="banner banner--danger">{feed.error}</div>
      ) : !experiences || experiences.length === 0 ? (
        <p className="card empty">No experiences here yet.</p>
      ) : (
        <div className="stack">
          {experiences.map((exp) => (
            <ExperienceCard key={exp.id} exp={exp} names={names} />
          ))}
        </div>
      )}
    </div>
  );
}
