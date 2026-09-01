// Scroll model: FRAMED_SCROLL (§16.14.7) — filters frame; the lesson list scrolls.
import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../api/client";
import type { Lesson } from "../api/types";
import { useApi } from "../lib/useApi";
import { useRetryFocus } from "../lib/useRetryFocus";
import { formatShortDate, formatTime, monthLabel } from "../lib/format";
import { staggerStyle , Skeleton } from "../lib/motion";

interface MonthGroup {
  label: string;
  lessons: Lesson[];
}

/** Lessons arrive chronologically ordered, so grouping preserves order. */
function groupByMonth(lessons: Lesson[]): MonthGroup[] {
  const groups: MonthGroup[] = [];
  for (const lesson of lessons) {
    const label = monthLabel(lesson.startsAt);
    const last = groups[groups.length - 1];
    if (last && last.label === label) last.lessons.push(lesson);
    else groups.push({ label, lessons: [lesson] });
  }
  return groups;
}

export function HistoryPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  // ?select=1: rows become pickable (used by the Experiences composer).
  const selectMode = searchParams.get("select") === "1";

  const [q, setQ] = useState("");
  const [debouncedQ, setDebouncedQ] = useState("");
  const [teacherId, setTeacherId] = useState("");
  const [courseId, setCourseId] = useState("");

  useEffect(() => {
    const t = setTimeout(() => setDebouncedQ(q), 300);
    return () => clearTimeout(t);
  }, [q]);

  const directory = useApi(() => api.directory(), [], "directory");
  const history = useApi(
    () =>
      api.history({
        order: "desc",
        limit: 200,
        ...(debouncedQ ? { q: debouncedQ } : {}),
        ...(teacherId ? { teacherId } : {}),
        ...(courseId ? { courseId } : {}),
      }),
    [debouncedQ, teacherId, courseId],
    `history:${JSON.stringify([debouncedQ, teacherId, courseId])}`,
  );
  const landing = useRetryFocus<HTMLDivElement>(history.loading);

  const groups = useMemo(() => groupByMonth(history.data?.lessons ?? []), [history.data]);

  return (
    <div>
      <h1 className="page-title">History</h1>
      {selectMode && (
        <div role="status" className="banner banner--success">
          Pick the lesson your experience is about.
        </div>
      )}

      <div className="filters">
        <input
          className="input"
          type="search"
          placeholder="Search lessons…"
          aria-label="Search lessons"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <select
          className="input"
          aria-label="Filter by teacher"
          value={teacherId}
          onChange={(e) => setTeacherId(e.target.value)}
        >
          <option value="">All teachers</option>
          {directory.data?.teachers.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
        <select
          className="input"
          aria-label="Filter by course"
          value={courseId}
          onChange={(e) => setCourseId(e.target.value)}
        >
          <option value="">All courses</option>
          {directory.data?.courses.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      <div ref={landing.ref} tabIndex={-1} className="focus-landing">
      {history.loading ? (
        <Skeleton lines={4} />
      ) : history.error ? (
        <div role="alert" className="banner banner--danger">
          <span>{history.error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); history.reload(); }}>
            Try again
          </button>
        </div>
      ) : groups.length === 0 ? (
        <p className="card empty">No lessons match.</p>
      ) : (
        groups.map((group) => (
          <section className="month-group" key={group.label}>
            <h2 className="month-group__label">{group.label}</h2>
            <ul className="month-group__list">
              {group.lessons.map((lesson, rowIndex) => (
                <li className="history-row stagger" style={staggerStyle(rowIndex)} key={lesson.id}>
                  <span className="history-row__date">
                    {formatShortDate(lesson.startsAt)}
                    <br />
                    {formatTime(lesson.startsAt)}
                  </span>
                  <span className="history-row__body">
                    <span>{lesson.subjectName}</span>
                    <span className="caption">
                      {[lesson.teacherName, lesson.roomName].filter(Boolean).join(" · ")}
                    </span>
                  </span>
                  {selectMode && (
                    <button
                      className="btn btn--ghost btn--small"
                      onClick={() => navigate(`/experiences/compose?lessonId=${lesson.id}`)}
                    >
                      Select
                    </button>
                  )}
                </li>
              ))}
            </ul>
          </section>
        ))
      )}
      </div>
    </div>
  );
}
