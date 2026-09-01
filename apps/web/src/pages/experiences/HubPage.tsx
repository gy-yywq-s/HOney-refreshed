// /experiences — the community hub: entity search, browse sections
// (Teachers / Places / Food), and the chronological "from your classes" feed.

import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, EntityType } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { Reveal , Skeleton } from "../../lib/motion";
import { ExperienceCard, entityPath, useFromYourClasses, useNames } from "./shared";

const SECTION_META: { type: EntityType; label: string }[] = [
  { type: "teacher", label: "Teachers" },
  { type: "room", label: "Places" },
  { type: "dish", label: "Food" },
];

const BROWSE_PREVIEW = 8;

export function ExperiencesHubPage() {
  const [q, setQ] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  useEffect(() => {
    const t = setTimeout(() => setDebouncedQ(q.trim()), 300);
    return () => clearTimeout(t);
  }, [q]);

  const entities = useApi(() => api.entities(), [], "entities");
  const search = useApi(
    () => (debouncedQ ? api.entities(undefined, debouncedQ) : Promise.resolve(null)),
    [debouncedQ],
    `entities:search:${debouncedQ}`,
  );
  const { names } = useNames();
  const fromClasses = useFromYourClasses();

  const byType = useMemo(() => {
    const groups: Record<EntityType, EntityRef[]> = { teacher: [], room: [], dish: [] };
    for (const e of entities.data?.entities ?? []) groups[e.type]?.push(e);
    return groups;
  }, [entities.data]);

  return (
    <div className="stack">
      <header className="section-head">
        <div>
          <span className="eyebrow">Experiences</span>
          <h1 className="page-title">A shared memory, read slowly</h1>
        </div>
        <Link className="btn btn--primary" to="/experiences/compose">
          Share an experience
        </Link>
      </header>
      <div className="text-3">
        Verified experiences from your school — more context, fewer verdicts.{" "}
        <Link to="/experiences/mine">My contributions</Link>
      </div>

      <input
        className="search-box"
        type="search"
        placeholder="Search teachers, places, food…"
        aria-label="Search entities by name"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />

      {debouncedQ ? (
        <section className="card" aria-label="Search results">
          <h2 className="overline">Results for “{debouncedQ}”</h2>
          {search.loading ? (
            <p className="muted">Searching…</p>
          ) : search.error ? (
            <div role="alert" className="banner banner--danger">{search.error}</div>
          ) : (search.data?.entities.length ?? 0) === 0 ? (
            <p className="empty">Nothing by that name.</p>
          ) : (
            <ul className="entity-list">
              {search.data!.entities.map((e) => (
                <EntityRow key={e.entity_key} entity={e} />
              ))}
            </ul>
          )}
        </section>
      ) : (
        <>
          {entities.error && <div role="alert" className="banner banner--danger">{entities.error}</div>}
          <div className="browse-grid">
            {SECTION_META.map(({ type, label }, sectionIndex) => (
              <Reveal as="section" index={sectionIndex} className="card lift" key={type} aria-label={label}>
                <h2 className="overline">{label}</h2>
                {entities.loading ? (
                  <Skeleton lines={3} />
                ) : byType[type].length === 0 ? (
                  <p className="empty">Nothing here yet.</p>
                ) : (
                  <ul className="entity-list">
                    {byType[type].slice(0, BROWSE_PREVIEW).map((e) => (
                      <EntityRow key={e.entity_key} entity={e} />
                    ))}
                  </ul>
                )}
                {byType[type].length > BROWSE_PREVIEW && (
                  <p className="caption">
                    {byType[type].length - BROWSE_PREVIEW} more — use search to find the rest.
                  </p>
                )}
              </Reveal>
            ))}
          </div>
        </>
      )}

      <Reveal as="section" aria-label="From your classes">
        <h2 className="overline">From your classes</h2>
        <p className="caption" style={{ marginTop: 0 }}>
          Experiences involving your own teachers and courses, newest first — chronological, never
          ranked.
        </p>
        {fromClasses.loading ? (
          <Skeleton lines={3} />
        ) : fromClasses.error ? (
          <div role="alert" className="banner banner--danger">{fromClasses.error}</div>
        ) : !fromClasses.experiences || fromClasses.experiences.length === 0 ? (
          <p className="card empty">
            Nothing from your classes yet. Import your timetable, or be the first to share one.
          </p>
        ) : (
          <div className="stack">
            {fromClasses.experiences.map((exp) => (
              <ExperienceCard key={exp.id} exp={exp} names={names} />
            ))}
          </div>
        )}
      </Reveal>
    </div>
  );
}

function EntityRow({ entity }: { entity: EntityRef }) {
  return (
    <li>
      <Link className="entity-row" to={entityPath(entity)}>
        <span>{entity.name}</span>
        <span className="caption">{entity.type === "room" ? "place" : entity.type === "dish" ? "food" : entity.type}</span>
      </Link>
    </li>
  );
}
