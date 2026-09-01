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

  // "From your history": the user's own imported teachers/courses — the most
  // likely lookup targets — surfaced first, still with everything listed below.
  const fromHistory = useMemo(() => {
    const dir = directory.data;
    if (!dir) return [];
    const known = new Set((entities.data?.entities ?? []).map((e) => e.entity_key));
    const refs: { key: string; name: string; path: string }[] = [];
    for (const t of dir.teachers) {
      if (known.has(`teacher:${t.id}`)) {
        refs.push({ key: `teacher:${t.id}`, name: t.name, path: `/experiences/teacher/${encodeURIComponent(t.id)}` });
      }
    }
    for (const c of dir.courses) {
      if (known.has(`course:${c.id}`)) {
        refs.push({ key: `course:${c.id}`, name: c.name, path: `/experiences/course/${encodeURIComponent(c.id)}` });
      }
    }
    return refs.slice(0, 10);
  }, [directory.data, entities.data]);

  return (
    <div className="stack explore">
      <header className="section-head">
        <div>
          <h1 className="page-title">Find someone or something</h1>
          <p className="muted" style={{ margin: 0 }}>
            Search teachers, courses, places, and food.
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
        aria-label="Filter entities by name"
        value={q}
        onChange={(e) => setQ(e.target.value)}
      />

      {!q && fromHistory.length > 0 && (
        <section aria-label="From your history">
          <h2 className="overline">From your history</h2>
          <div className="history-chips">
            {fromHistory.map((r) => (
              <Link key={r.key} className="history-chip" to={r.path}>
                {r.name}
              </Link>
            ))}
          </div>
        </section>
      )}
      {entities.error && <div role="alert" className="banner banner--danger">{entities.error}</div>}
      {entities.loading ? (
        <Skeleton lines={6} />
      ) : (
        SECTIONS.map(({ type, label }) => (
          <ExploreSection key={type} label={label} items={byType[type]} filtered={q.trim().length > 0} />
        ))
      )}
    </div>
  );
}

function ExploreSection({
  label,
  items,
  filtered,
}: {
  label: string;
  items: EntityRef[];
  filtered: boolean;
}) {
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
                <ExploreRow key={e.entity_key} entity={e} />
              ))}
            </ul>
          </div>
        ))
      ) : (
        <ul className="entity-list">
          {items.map((e) => (
            <ExploreRow key={e.entity_key} entity={e} />
          ))}
        </ul>
      )}
    </section>
  );
}

function ExploreRow({ entity }: { entity: EntityRef }) {
  return (
    <li>
      <Link className="entity-row" to={entityPath(entity)}>
        <span>{entity.name}</span>
      </Link>
    </li>
  );
}
