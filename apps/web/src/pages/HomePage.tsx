import { Link } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { useApi } from "../lib/useApi";
import { formatTime, isStale, timeAgo } from "../lib/format";

export function HomePage() {
  const { me } = useAuth();
  const { data, error, loading } = useApi(() => api.nextLesson(), []);
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
        <h2 className="section-title">Experiences</h2>
        <p className="muted">
          Anonymous notes on lessons, teachers, places and food — arriving with the community
          backend.
        </p>
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
