import { Link } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { useApi } from "../lib/useApi";
import { formatDayBucket, formatTime, isStale, timeAgo, todayIsoDate } from "../lib/format";
import { Reveal, useCountUp, useNowTick , Skeleton } from "../lib/motion";
import { provenanceLabel, useFromYourClasses } from "./experiences/shared";

export function HomePage() {
  const { me } = useAuth();
  const { data, error, loading } = useApi(() => api.nextLesson(), [], "next-lesson");
  const today = useApi(() => api.timetable(todayIsoDate()), [], `timetable:${todayIsoDate()}`);
  const fromClasses = useFromYourClasses(30);
  const now = useNowTick(1000);

  // Stat-strip count-ups (hooks stay above the early return).
  const lessonsToday = useCountUp(today.data ? today.data.lessons.length : null);
  const fromClassesCount = useCountUp(
    fromClasses.experiences ? fromClasses.experiences.length : null,
  );

  if (!me) return null;

  const next = data?.nextLesson ?? null;
  const lastSyncedAt = data?.lastSyncedAt ?? null;
  // Legacy HomeLessonSummaryCard behavior kept: a running lesson fills the
  // card with an accent wash, left-to-right, proportional to elapsed time.
  const progress =
    next && next.temporalState === "now"
      ? Math.min(1, Math.max(0, (now - next.startsAt) / Math.max(1, next.endsAt - next.startsAt)))
      : null;

  // Live countdown to the next lesson (ticks with the clock).
  const minutesToNext =
    next && next.temporalState !== "now"
      ? Math.max(0, Math.ceil((next.startsAt - now) / 60_000))
      : null;

  return (
    <div className="stack">
      <header className="hero home-greeting">
        <h1 className="sweep-host">
          <span className="parallax-faint">Hi,</span>
          <span className="hero__accent parallax-slow">{me.displayName}</span>
        </h1>
        <p className="home-greeting__sub hero-copy">
          {lastSyncedAt && isStale(lastSyncedAt)
            ? `Last synced ${timeAgo(lastSyncedAt)}`
            : "Here's your day."}
        </p>
      </header>

      <Reveal as="section" className="card card--hero nextlesson" aria-label="Next lesson">
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
          <Skeleton lines={2} />
        ) : error ? (
          <div role="alert" className="banner banner--danger">{error}</div>
        ) : next ? (
          <>
            <span className="nextlesson__state">
              {next.temporalState === "now"
                ? "Now"
                : `in ${minutesToNext ?? next.minutesUntilStart} min`}
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
      </Reveal>

      <Reveal as="section" index={1} className="stat-strip" aria-label="Today in numbers">
        <div className="stat">
          <strong>{today.loading ? "…" : (lessonsToday ?? "—")}</strong>
          <span>Lessons today</span>
        </div>
        <div className="stat">
          <strong>
            {loading
              ? "…"
              : next
                ? next.temporalState === "now"
                  ? "Now"
                  : `${minutesToNext ?? next.minutesUntilStart}′`
                : "—"}
          </strong>
          <span>{next && next.temporalState === "now" ? "Lesson running" : "Until next lesson"}</span>
        </div>
        <div className="stat">
          <strong>{fromClasses.loading ? "…" : (fromClassesCount ?? "—")}</strong>
          <span>Recent posts from your classes</span>
        </div>
      </Reveal>

      {/* Numbered action cards — the hub, the day, the school portal. */}
      <div className="action-grid">
        <Reveal as="section" index={2} className="action-card primary glow" aria-label="Experiences">
          <span className="card-index">01 · Community</span>
          <span className="card-title">Experiences</span>
          <p className="card-copy">A shared memory of lessons, teachers, places and food.</p>
          <span>
            <Link className="action-cta" to="/experiences/compose">
              Share an experience
            </Link>
          </span>
        </Reveal>
        <Reveal as="section" index={3} className="action-card glow" aria-label="Timetable">
          <span className="card-index">02 · Schedule</span>
          <span className="card-title">Timetable</span>
          <p className="card-copy">Your day, drawn to scale on the Day canvas.</p>
          <span>
            <Link className="action-cta" to="/timetable">
              Open timetable
            </Link>
          </span>
        </Reveal>
        <Reveal as="section" index={4} className="action-card glow" aria-label="School Portal">
          <span className="card-index">03 · School</span>
          <span className="card-title">School Portal</span>
          <p className="card-copy">The official school site, one hop away.</p>
          <span>
            <a
              className="action-cta"
              href="https://www.huayaopudong.com/student/notification"
              target="_blank"
              rel="noopener noreferrer"
            >
              School Portal <span aria-hidden="true">&#8599;</span>
            </a>
          </span>
        </Reveal>
      </div>

      <Reveal as="section" index={5} className="card" aria-label="Experiences">
        <span className="eyebrow">From your classes</span>
        {fromClasses.loading ? (
          <Skeleton lines={2} />
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
        {/* No Share/Browse pair here — action card 01 and the nav already
            carry both (design audit 2026-09-01, fix 4). Link onward only when
            there is something to continue reading. */}
        {!fromClasses.loading &&
          !fromClasses.error &&
          (fromClasses.experiences?.length ?? 0) > 0 && (
            <div className="card-actions">
              <Link className="btn btn--ghost" to="/experiences">
                Keep reading
              </Link>
            </div>
          )}
      </Reveal>
    </div>
  );
}
