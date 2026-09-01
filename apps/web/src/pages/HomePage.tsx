// Home has ONE job (review v3 §6.2): know what's now / next in three seconds,
// and lightly feel that other students are speaking. Composition (§6.3):
// compact greeting + date → focal Now/Next object → 1–2 raw experience
// previews → Share something + a quiet School Portal row. No stat strips, no
// numbered action grid, no feature copy. Scroll model: COMPACT_OVERFLOW.

import { Link } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { useApi } from "../lib/useApi";
import { formatDayBucket, formatRemaining, formatTime, isStale, timeAgo } from "../lib/format";
import { Skeleton, useNowTick } from "../lib/motion";
import { useFromYourClasses } from "./experiences/shared";

export function HomePage() {
  const { me } = useAuth();
  const { data, error, loading, reload } = useApi(() => api.nextLesson(), [], "next-lesson");
  const fromClasses = useFromYourClasses(10);
  const now = useNowTick(1000);

  if (!me) return null;

  const next = data?.nextLesson ?? null;
  const lastSyncedAt = data?.lastSyncedAt ?? null;
  // Legacy behavior kept: a running lesson fills the focal object with an
  // accent wash, left-to-right, proportional to elapsed time — motion that
  // explains state (review v3 §5.5.3 keeps exactly this kind).
  const progress =
    next && next.temporalState === "now"
      ? Math.min(1, Math.max(0, (now - next.startsAt) / Math.max(1, next.endsAt - next.startsAt)))
      : null;
  // Humanized: "In 45 min" same-day, "Tomorrow · 13:30" / "Thursday · 13:30"
  // beyond — never "In 618 min" (Gary + copy audit 2026-09-01).
  const stateChip = (() => {
    if (!next) return null;
    if (next.temporalState === "now") return "Now";
    const start = new Date(next.startsAt);
    const sameDay = start.toDateString() === new Date(now).toDateString();
    if (sameDay) return `In ${formatRemaining(next.startsAt - now)}`;
    const tomorrow = start.toDateString() === new Date(now + 86_400_000).toDateString();
    const day = tomorrow ? "Tomorrow" : start.toLocaleDateString("en-GB", { weekday: "long" });
    return `${day} · ${formatTime(next.startsAt)}`;
  })();

  const today = new Date(now).toLocaleDateString("en-GB", {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
  const previews = (fromClasses.experiences ?? []).filter((e) => e.body).slice(0, 2);

  return (
    <div className="stack home">
      <header className="home-head">
        <h1 className="home-head__hi">Hi, {me.displayName}</h1>
        <p className="home-head__date">
          {today}
          {lastSyncedAt && isStale(lastSyncedAt) && (
            <span className="home-head__stale"> · last synced {timeAgo(lastSyncedAt)}</span>
          )}
        </p>
      </header>

      <section className="card card--hero nextlesson" aria-label="Now and next">
        {progress !== null && (
          <div
            className="nextlesson__wash"
            style={{ width: `${(progress * 100).toFixed(1)}%` }}
            aria-hidden="true"
          />
        )}
        <span className="eyebrow">{next?.temporalState === "now" ? "Now" : "Next"}</span>
        {loading ? (
          <Skeleton lines={2} />
        ) : error ? (
          <div role="alert" className="banner banner--danger">
          <span>{error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => reload()}>
            Try again
          </button>
        </div>
        ) : next ? (
          <>
            <span className="nextlesson__state">{stateChip}</span>
            <div className="nextlesson__subject">{next.subjectName}</div>
            <p className="muted">
              {formatTime(next.startsAt)}–{formatTime(next.endsAt)}
              {next.teacherName ? ` · ${next.teacherName}` : ""}
              {next.roomName ? ` · ${next.roomName}` : ""}
            </p>
            <Link className="caption" to="/timetable">
              Open timetable
            </Link>
          </>
        ) : (
          <>
            <p className="empty">No upcoming lessons in your imported timetable.</p>
            <Link className="caption" to="/timetable">
              Open timetable
            </Link>
          </>
        )}
      </section>

      <section className="home-voices" aria-label="From your classes">
        <div className="home-voices__head">
          <span className="eyebrow">From your classes</span>
        </div>
        {fromClasses.loading ? (
          <Skeleton lines={2} />
        ) : fromClasses.error || previews.length === 0 ? (
          <p className="muted home-voices__empty">
            When someone shares an experience connected to your classes, it will appear here.
          </p>
        ) : (
          <ul className="home-voices__list">
            {/* Chronological, 1–2 only — a glimpse, not a mini feed (§6.4). */}
            {previews.map((exp) => (
              <li key={exp.id} className="home-voices__row">
                <Link to="/experiences" className="home-voices__body">
                  {exp.body}
                </Link>
                <span className="caption">
                  {[
                    exp.contexts?.find((c) => c.type === "course")?.name,
                    exp.contexts?.find((c) => c.type === "teacher")?.name ??
                      (exp.primary?.type !== "lesson" ? exp.primary?.name : null),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                  {exp.publishedDay !== null ? ` · ${formatDayBucket(exp.publishedDay)}` : ""}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <div className="home-foot">
        <Link className="btn btn--primary" to="/experiences/compose">
          Share something
        </Link>
        <a
          className="portal-row"
          href="https://www.huayaopudong.com/student/notification"
          target="_blank"
          rel="noopener noreferrer"
        >
          <span>School Portal</span>
          <span className="caption">
            Open the official site <span aria-hidden="true">&#8599;</span>
          </span>
        </a>
      </div>
    </div>
  );
}
