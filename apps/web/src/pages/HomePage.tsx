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

  return (
    <div className="stack">
      <header>
        <h1 className="page-title">Welcome, {me.displayName}</h1>
        {lastSyncedAt && isStale(lastSyncedAt) && (
          <span className="caption">Last synced {timeAgo(lastSyncedAt)}</span>
        )}
      </header>

      <section className="card" aria-label="Next lesson">
        <h2 className="section-title">Next lesson</h2>
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
        <h2 className="section-title">Recent from your classes</h2>
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
            {/* Chronological (newest first), no ranking — first three only. */}
            {fromClasses.experiences.slice(0, 3).map((exp) => (
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
