// /experiences/explore — the deliberate lookup mode (review v1.1 §6): a
// framed finder, not a directory document. The search field and the
// category chips stay in the frame while the result region scrolls; one
// category is browsable at a time (Teachers / Courses / Places / Food) and
// EVERY entity in it is listed (owner rule 4f — never "use search to find
// the rest"). Typing filters every category and, from two characters,
// also finds published experiences that mention the words. Raw portal
// course strings are split into title + metadata for display.
// Scroll model: FRAMED_EDITOR/FRAMED_SCROLL hybrid.

import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, EntityType } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { ExperiencePost } from "../../features/experiences/ExperiencePost";
import { recentContexts } from "../../lib/recentContexts";
import { entityMeta, entityTitle } from "../../lib/displayNames";
import { useRetryFocus } from "../../lib/useRetryFocus";
import { Skeleton } from "../../lib/motion";
import { ChevronRightIcon, CloseIcon, SearchIcon } from "../../components/icons";
import { entityPath } from "./shared";

const SECTIONS: { type: EntityType; label: string }[] = [
  { type: "teacher", label: "Teachers" },
  { type: "course", label: "Courses" },
  { type: "room", label: "Places" },
  { type: "dish", label: "Food" },
];

/** Group by first letter once a section is long enough to need landmarks. */
const GROUP_THRESHOLD = 18;
const STATE_KEY = "honey.explore.state"; // query + category survive a round trip

function restore(): { q: string; cat: EntityType } {
  try {
    const raw = sessionStorage.getItem(STATE_KEY);
    if (raw) {
      const s = JSON.parse(raw) as { q?: string; cat?: EntityType };
      if (s.cat && SECTIONS.some((x) => x.type === s.cat)) return { q: s.q ?? "", cat: s.cat };
    }
  } catch {
    /* no session storage */
  }
  return { q: "", cat: "teacher" };
}

export function ExperiencesExplorePage() {
  const initial = useMemo(restore, []);
  const [q, setQ] = useState(initial.q);
  const [cat, setCat] = useState<EntityType>(initial.cat);
  useEffect(() => {
    try {
      sessionStorage.setItem(STATE_KEY, JSON.stringify({ q, cat }));
    } catch {
      /* ignore */
    }
  }, [q, cat]);

  const entities = useApi(() => api.entities(), [], "entities");
  const directory = useApi(() => api.directory(), [], "directory");
  // Find mode: from two characters the server also searches the words of
  // published experiences — debounced, cached per query, with its own
  // loading / error / empty states (r10).
  const [debounced, setDebounced] = useState(q.trim());
  useEffect(() => {
    const t = window.setTimeout(() => setDebounced(q.trim()), 250);
    return () => window.clearTimeout(t);
  }, [q]);
  const searchQ = debounced.length >= 2 ? debounced : "";
  const search = useApi(
    () => (searchQ ? api.search(searchQ) : Promise.resolve(null)),
    [searchQ],
    searchQ ? `search:${searchQ}` : undefined,
  );
  const recent = recentContexts.list();
  // Arm on every flag a retry on this page reloads (r9 contract).
  const landing = useRetryFocus<HTMLDivElement>(entities.loading || directory.loading || search.loading);

  const needle = q.trim().toLowerCase();
  const byType = useMemo(() => {
    const groups: Record<EntityType, EntityRef[]> = { teacher: [], course: [], room: [], dish: [] };
    for (const e of entities.data?.entities ?? []) {
      if (needle && !e.name.toLowerCase().includes(needle)) continue;
      groups[e.type]?.push(e);
    }
    for (const list of Object.values(groups)) list.sort((a, b) => a.name.localeCompare(b.name));
    return groups;
  }, [entities.data, needle]);
  const totals = useMemo(() => {
    const t: Record<EntityType, number> = { teacher: 0, course: 0, room: 0, dish: 0 };
    for (const e of entities.data?.entities ?? []) t[e.type] = (t[e.type] ?? 0) + 1;
    return t;
  }, [entities.data]);

  // "From your classes": the student's own imported teachers/courses are
  // MARKED inline in the complete listing (design-is r2).
  const fromHistory = useMemo(() => {
    const dir = directory.data;
    if (!dir) return new Set<string>();
    const known = new Set((entities.data?.entities ?? []).map((e) => e.entity_key));
    const mine = new Set<string>();
    for (const t of dir.teachers) if (known.has(`teacher:${t.id}`)) mine.add(`teacher:${t.id}`);
    for (const c of dir.courses) if (known.has(`course:${c.id}`)) mine.add(`course:${c.id}`);
    return mine;
  }, [directory.data, entities.data]);

  const matches = needle ? SECTIONS.filter((s) => byType[s.type].length > 0) : [];
  const nameCount = needle ? matches.reduce((n, s) => n + byType[s.type].length, 0) : 0;
  const status = !needle
    ? ""
    : searchQ && search.loading
      ? `${nameCount} names, searching experiences`
      : `${nameCount} names${searchQ && search.data ? `, ${search.data.experiences.length} experiences` : ""}`;

  return (
    <div className="stack explore">
      <header className="explore-head">
        <h1 className="page-title">Explore</h1>
        <p className="muted explore-head__sub">Teachers, courses, places and food.</p>
      </header>

      <div className="explore-frame">
        <div className="search-field">
          <span className="search-field__glyph">
            <SearchIcon size={18} />
          </span>
          <input
            className="search-box"
            type="search"
            placeholder="Search names and experiences"
            aria-label="Search names and experiences"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          {q && (
            <button type="button" className="search-field__clear" aria-label="Clear search" onClick={() => setQ("")}>
              <CloseIcon size={16} />
            </button>
          )}
        </div>
        {!needle && (
          <div className="cat-chips" role="tablist" aria-label="Category">
            {SECTIONS.map((s) => (
              <button
                key={s.type}
                type="button"
                role="tab"
                aria-selected={cat === s.type}
                className="chip-tab"
                onClick={() => setCat(s.type)}
              >
                {s.label}
                {entities.data && <span className="chip-tab__n">{totals[s.type]}</span>}
              </button>
            ))}
          </div>
        )}
      </div>

      {(entities.error || directory.error) && (
        <div role="alert" className="banner banner--danger">
          <span>{entities.error ?? directory.error}</span>
          <button
            className="btn btn--ghost btn--small"
            onClick={() => {
              landing.arm();
              if (entities.error) entities.reload();
              if (directory.error) directory.reload();
            }}
          >
            Try again
          </button>
        </div>
      )}

      <div ref={landing.ref} tabIndex={-1} className="focus-landing explore-results" role="group" aria-label="Results">
        <p className="sr-only" role="status">
          {status}
        </p>
        {entities.loading ? (
          <Skeleton lines={6} />
        ) : entities.error ? null : needle ? (
          matches.length === 0 ? (
            <p className="empty">Nothing by that name.</p>
          ) : (
            matches.map((s) => (
              <ExploreSection
                key={s.type}
                label={s.label}
                count={`${byType[s.type].length} of ${totals[s.type]}`}
                items={byType[s.type]}
                mine={fromHistory}
              />
            ))
          )
        ) : (
          <>
            {recent.length > 0 && (
              <section aria-label="Recently opened" className="explore-recent">
                <h2 className="overline">Recently opened</h2>
                <ul className="entity-list">
                  {recent.map((r) => (
                    <li key={r.path}>
                      <Link className="entity-row" to={r.path}>
                        <span className="entity-row__main">
                          <span className="entity-row__title">{r.name}</span>
                        </span>
                        <ChevronRightIcon size={18} />
                      </Link>
                    </li>
                  ))}
                </ul>
              </section>
            )}
            <ExploreSection
              key={cat}
              label={SECTIONS.find((s) => s.type === cat)!.label}
              count={String(totals[cat])}
              items={byType[cat]}
              mine={fromHistory}
            />
          </>
        )}
        {searchQ && (
          <section aria-labelledby="explore-mentions" className="explore-mentions">
            <h2 className="overline" id="explore-mentions">
              Experiences that mention “{searchQ}”
            </h2>
            {search.loading ? (
              <Skeleton lines={4} />
            ) : search.error ? (
              <div role="alert" className="banner banner--danger">
                <span>{search.error}</span>
                <button
                  className="btn btn--ghost btn--small"
                  onClick={() => {
                    landing.arm();
                    search.reload();
                  }}
                >
                  Try again
                </button>
              </div>
            ) : search.data && search.data.experiences.length > 0 ? (
              <div className="feed-stream">
                {search.data.experiences.map((exp) => (
                  <ExperiencePost key={exp.id} exp={exp} />
                ))}
              </div>
            ) : (
              <p className="caption">No experiences mention “{searchQ}”.</p>
            )}
          </section>
        )}
      </div>
    </div>
  );
}

function ExploreSection({
  label,
  count,
  items,
  mine,
}: {
  label: string;
  count: string;
  items: EntityRef[];
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
        {label} <span className="caption">{count}</span>
      </h2>
      {items.length === 0 ? (
        <p className="empty">Nothing here yet.</p>
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
  const title = entityTitle(entity.type, entity.name);
  const meta = entityMeta(entity.type, entity.name);
  return (
    <li>
      <Link
        className="entity-row"
        to={entityPath(entity)}
        onClick={() => recentContexts.remember({ name: title, path: entityPath(entity) })}
      >
        <span className="entity-row__main">
          <span className="entity-row__title">{title}</span>
          {(meta || mine) && (
            <span className="caption">
              {meta}
              {mine && (
                <>
                  {meta ? " · " : ""}
                  <span className="sr-only">, </span>from your classes
                </>
              )}
            </span>
          )}
        </span>
        <ChevronRightIcon size={18} />
      </Link>
    </li>
  );
}
