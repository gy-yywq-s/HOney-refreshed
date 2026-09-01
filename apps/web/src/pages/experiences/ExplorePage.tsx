// /experiences/explore — the deliberate lookup mode (review v3 §9.10):
// entity search over teachers / courses / places / food. EVERY selectable
// entity is displayed (owner rule 4f — never "use search to find the rest");
// the search box only narrows the complete listing. Long sections group by
// first letter so the full set stays scannable, not messy.
// Scroll model: FRAMED_EDITOR/FRAMED_SCROLL hybrid (web-lab.md).

import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, EntityType } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { useRetryFocus } from "../../lib/useRetryFocus";
import { Skeleton } from "../../lib/motion";
import { entityPath } from "./shared";

const SECTIONS: { type: EntityType; label: string }[] = [
  { type: "teacher", label: "Teachers" },
  { type: "course", label: "Courses" },
  { type: "room", label: "Places" },
  { type: "dish", label: "Food" },
];

/** Group by first letter once a section is long enough to need landmarks. */
const GROUP_THRESHOLD = 18;

export function ExperiencesExplorePage() {
  const [q, setQ] = useState("");
  const entities = useApi(() => api.entities(), [], "entities");
  const directory = useApi(() => api.directory(), [], "directory");
  const landing = useRetryFocus<HTMLDivElement>(entities.loading);

  const byType = useMemo(() => {
    const groups: Record<EntityType, EntityRef[]> = { teacher: [], course: [], room: [], dish: [] };
    const needle = q.trim().toLowerCase();
    for (const e of entities.data?.entities ?? []) {
      if (needle && !e.name.toLowerCase().includes(needle)) continue;
      groups[e.type]?.push(e);
    }
    for (const list of Object.values(groups)) list.sort((a, b) => a.name.localeCompare(b.name));
    return groups;
  }, [entities.data, q]);

  // "From your history": the user's own imported teachers/courses are the
  // most likely lookup targets. They are MARKED inline in the complete
  // listing (design-is r2: a separate strip repeated 9 of 10 names).
  const fromHistory = useMemo(() => {
    const dir = directory.data;
    if (!dir) return new Set<string>();
    const known = new Set((entities.data?.entities ?? []).map((e) => e.entity_key));
    const mine = new Set<string>();
    for (const t of dir.teachers) if (known.has(`teacher:${t.id}`)) mine.add(`teacher:${t.id}`);
    for (const c of dir.courses) if (known.has(`course:${c.id}`)) mine.add(`course:${c.id}`);
    return mine;
  }, [directory.data, entities.data]);

  return (
    <div className="stack explore">
      <header className="section-head">
        <div>
          <h1 className="page-title">Find someone or something</h1>
          <p className="muted" style={{ margin: 0 }}>
            Teachers, courses, places and food are all listed below — typing only narrows the list.
          </p>
        </div>
        <Link className="btn btn--ghost" to="/experiences">
          Back to Experiences
        </Link>
      </header>

      <input
        className="search-box"
        type="search"
        placeholder="Filter by name…"
        aria-label="Filter by name"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />

      {entities.error && (
        <div role="alert" className="banner banner--danger">
          <span>{entities.error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); entities.reload(); }}>
            Try again
          </button>
        </div>
      )}
      <div ref={landing.ref} tabIndex={-1} className="focus-landing">
      {entities.loading ? (
        <Skeleton lines={6} />
      ) : (
        SECTIONS.map(({ type, label }) => (
          <ExploreSection
            key={type}
            label={label}
            items={byType[type]}
            filtered={q.trim().length > 0}
            mine={fromHistory}
          />
        ))
      )}
      </div>
    </div>
  );
}

function ExploreSection({
  label,
  items,
  filtered,
  mine,
}: {
  label: string;
  items: EntityRef[];
  filtered: boolean;
  mine: Set<string>;
}) {
  // The mark only earns its place where it distinguishes: if every row in the
  // section is from the student's own classes, nothing is marked (r3).
  const markable = items.some((e) => mine.has(e.entity_key)) && items.some((e) => !mine.has(e.entity_key));
  // The COMPLETE listing, always (rule 4f). Letter groups keep it scannable.
  const grouped = useMemo(() => {
    if (items.length < GROUP_THRESHOLD) return null;
    const map = new Map<string, EntityRef[]>();
    for (const e of items) {
      const letter = (e.name[0] ?? "#").toUpperCase();
      const key = /[A-Z]/.test(letter) ? letter : "#";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(e);
    }
    return [...map.entries()].sort(([a], [b]) => a.localeCompare(b));
  }, [items]);

  return (
    <section aria-label={label}>
      <h2 className="overline">
        {label} <span className="caption">{items.length}</span>
      </h2>
      {items.length === 0 ? (
        <p className="empty">{filtered ? "Nothing by that name." : "Nothing here yet."}</p>
      ) : grouped ? (
        grouped.map(([letter, list]) => (
          <div key={letter} className="explore-letter">
            <span className="explore-letter__mark">{letter}</span>
            <ul className="entity-list">
              {list.map((e) => (
                <ExploreRow key={e.entity_key} entity={e} mine={markable && mine.has(e.entity_key)} />
              ))}
            </ul>
          </div>
        ))
      ) : (
        <ul className="entity-list">
          {items.map((e) => (
            <ExploreRow key={e.entity_key} entity={e} mine={markable && mine.has(e.entity_key)} />
          ))}
        </ul>
      )}
    </section>
  );
}

function ExploreRow({ entity, mine }: { entity: EntityRef; mine: boolean }) {
  return (
    <li>
      <Link className="entity-row" to={entityPath(entity)}>
        <span>{entity.name}</span>
        {mine && (
          <span className="caption">
            <span className="sr-only">, </span>from your classes
          </span>
        )}
      </Link>
    </li>
  );
}
