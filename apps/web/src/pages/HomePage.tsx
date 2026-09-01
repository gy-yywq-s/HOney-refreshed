import { Link } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { useApi } from "../lib/useApi";
import { formatDayBucket, formatTime, isStale, timeAgo } from "../lib/format";
import { provenanceLabel, useFromYourClasses } from "./experiences/shared";

export function HomePage() {
  const { me } = useAuth();
  const { data, error, loading } = useApi(() => api.nextLesson(), []);
  const fromClasses = useFromYourClasses(30);
  if (!me) return null;

  const next = data?.nextLesson ?? null;
  const lastSyncedAt = data?.lastSyncedAt ?? null;
  // Legacy HomeLessonSummaryCard: a running lesson fills the card with an
  // ocean@0.67 wash, left-to-right, proportional to elapsed time.
  const progress =
    next && next.temporalState === "now"
      ? Math.min(1, Math.max(0, (Date.now() - next.startsAt) / Math.max(1, next.endsAt - next.startsAt)))
      : null;

  return (
    <div className="stack">
      <header className="home-greeting">
        <h1 className="home-greeting__hi">Hi, {me.displayName}</h1>
        <p className="home-greeting__sub text-3">
          {lastSyncedAt && isStale(lastSyncedAt)
            ? `Last synced ${timeAgo(lastSyncedAt)}`
            : "Here's your day."}
        </p>
      </header>

      <section className="card card--hero nextlesson" aria-label="Next lesson">
        {progress !== null && (
          <div
            className="nextlesson__wash"
            style={{ width: `${(progress * 100).toFixed(1)}%` }}
            aria-hidden="true"
          />
        )}
        <span className="eyebrow">
          {next?.temporalState === "now" ? "Current lesson" : "Next lesson"}
        </span>
        {loading ? (
          <p className="muted">Loading…</p>
        ) : error ? (
          <div className="banner banner--danger">{error}</div>
        ) : next ? (
          <>
            <span className="nextlesson__state">
              {next.temporalState === "now" ? "Now" : `in ${next.minutesUntilStart} min`}
            </span>
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
          <p className="empty">No more lessons today</p>
        )}
      </section>

      <section className="card" aria-label="Experiences">
        <span className="eyebrow">From your classes</span>
        {fromClasses.loading ? (
          <p className="muted">Loading…</p>
        ) : fromClasses.error ? (
          <p className="muted">Experiences are unavailable right now.</p>
        ) : !fromClasses.experiences || fromClasses.experiences.length === 0 ? (
          <p className="muted">
            No experiences from your teachers and courses yet — be the first to share one.
          </p>
        ) : (
          <ul className="home-exp-list">
            {/* Chronological (newest first), no ranking — a small glimpse only. */}
            {fromClasses.experiences.slice(0, 2).map((exp) => (
              <li key={exp.id} className="home-exp-row">
                <span className="home-exp-row__body">{exp.body}</span>
                <span className="caption">
                  {provenanceLabel(exp.provenance)}
                  {exp.publishedDay !== null ? ` · ${formatDayBucket(exp.publishedDay)}` : ""}
                </span>
              </li>
            ))}
          </ul>
        )}
        <div className="card-actions">
          <Link className="btn btn--primary" to="/experiences/compose">
            Share an experience
          </Link>
          <Link className="btn btn--ghost" to="/experiences">
            Browse Experiences
          </Link>
        </div>
      </section>

      <a
        className="card row-link"
        href="https://www.huayaopudong.com"
        target="_blank"
        rel="noopener noreferrer"
      >
        <span>School Portal</span>
        <span aria-hidden="true">&#8599;</span>
      </a>
    </div>
  );
}
