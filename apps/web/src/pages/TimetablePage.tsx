import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import type { Lesson, SyncResponse } from "../api/types";
import { Modal } from "../components/Modal";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { useApi } from "../lib/useApi";
import {
  formatDayHeading,
  formatTime,
  shiftIsoDate,
  timeAgo,
  todayIsoDate,
} from "../lib/format";

type SyncFeedback = { kind: "result"; result: SyncResponse } | { kind: "error"; message: string };

export function TimetablePage() {
  const [date, setDate] = useState(todayIsoDate());
  const { data, error, loading, reload } = useApi(() => api.timetable(date), [date]);
  const [selected, setSelected] = useState<Lesson | null>(null);
  const [syncBusy, setSyncBusy] = useState(false);
  const [syncFeedback, setSyncFeedback] = useState<SyncFeedback | null>(null);
  const [showReconnect, setShowReconnect] = useState(false);

  async function runSync() {
    setSyncBusy(true);
    setSyncFeedback(null);
    try {
      const result = await api.sync();
      setSyncFeedback({ kind: "result", result });
      if (result.status === "ok") reload();
    } catch (err) {
      setSyncFeedback({ kind: "error", message: describeApiError(err) });
    } finally {
      setSyncBusy(false);
    }
  }

  return (
    <div>
      <div className="daynav">
        <button
          className="btn btn--ghost"
          aria-label="Previous day"
          onClick={() => setDate((d) => shiftIsoDate(d, -1))}
        >
          &lsaquo;
        </button>
        <button
          className="btn btn--ghost"
          aria-label="Next day"
          onClick={() => setDate((d) => shiftIsoDate(d, 1))}
        >
          &rsaquo;
        </button>
        <button className="btn btn--ghost" onClick={() => setDate(todayIsoDate())}>
          Today
        </button>
        <input
          className="input"
          type="date"
          aria-label="Pick a date"
          value={date}
          onChange={(e) => e.target.value && setDate(e.target.value)}
        />
        <span className="daynav__spacer" />
        <Link className="btn btn--ghost" to="/history">
          History
        </Link>
        <button className="btn btn--primary" onClick={() => void runSync()} disabled={syncBusy}>
          {syncBusy ? "Syncing…" : "Sync"}
        </button>
      </div>

      <h1 className="schedule-header">{formatDayHeading(date)}</h1>

      {syncFeedback?.kind === "error" && (
        <div className="banner banner--danger">{syncFeedback.message}</div>
      )}
      {syncFeedback?.kind === "result" && syncFeedback.result.status === "ok" && (
        <div className="banner banner--success">
          Synced {syncFeedback.result.lessons} lessons from the school portal.
        </div>
      )}
      {syncFeedback?.kind === "result" && syncFeedback.result.status === "no_consent" && (
        <div className="banner banner--warning">
          <span>Timetable import is switched off, so there is nothing to sync.</span>
          <Link className="btn btn--ghost btn--small" to="/settings">
            Open Settings
          </Link>
        </div>
      )}
      {syncFeedback?.kind === "result" &&
        syncFeedback.result.status === "portal_reconnect_required" && (
          <div className="banner banner--warning">
            <span>HOney lost its connection to the school portal.</span>
            <button className="btn btn--ghost btn--small" onClick={() => setShowReconnect(true)}>
              Reconnect
            </button>
          </div>
        )}

      {loading ? (
        <p className="fullscreen-note">Loading…</p>
      ) : error ? (
        <div className="banner banner--danger">{error}</div>
      ) : (
        <>
          <DayTimeline
            date={date}
            lessons={data?.lessons ?? []}
            onSelect={(lesson) => setSelected(lesson)}
          />
          {data?.lastSyncedAt && (
            <p className="caption" style={{ marginTop: "var(--space-md)" }}>
              Last synced {timeAgo(data.lastSyncedAt)}
            </p>
          )}
        </>
      )}

      {selected && <LessonDetail lesson={selected} onClose={() => setSelected(null)} />}
      {showReconnect && (
        <ReconnectDialog
          onClose={() => setShowReconnect(false)}
          onReconnected={() => void runSync()}
        />
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// The Day timeline — a faithful port of the legacy DayTimelineView: a
// 09:00-20:00 canvas, pastel period bands
// (green Lunch/Dinner breaks with a leaf glyph), "P3 · Free" ghost labels,
// hour gridlines and the red now-line. Lessons are positioned by wall time.
// ---------------------------------------------------------------------------

const DAY_START = 9 * 60;
const DAY_END = 20 * 60;

interface TimelineBand {
  id: string;
  start: number;
  end: number;
  kind: "period" | "break";
  /** Period number, or the break's label. */
  period?: number;
  label?: string;
}

/** Legacy TimelineBand.standard, verbatim. */
const BANDS: TimelineBand[] = [
  { id: "p1", start: 9 * 60, end: 10 * 60 + 30, kind: "period", period: 1 },
  { id: "p2", start: 10 * 60 + 30, end: 12 * 60, kind: "period", period: 2 },
  { id: "lunch", start: 12 * 60, end: 13 * 60 + 30, kind: "break", label: "Lunch Break" },
  { id: "p3", start: 13 * 60 + 30, end: 15 * 60, kind: "period", period: 3 },
  { id: "p4", start: 15 * 60, end: 16 * 60 + 30, kind: "period", period: 4 },
  { id: "p5", start: 16 * 60 + 30, end: 18 * 60, kind: "period", period: 5 },
  { id: "dinner", start: 18 * 60, end: 18 * 60 + 30, kind: "break", label: "Dinner Break" },
  { id: "p6", start: 18 * 60 + 30, end: 20 * 60, kind: "period", period: 6 },
];

const PERIODS = BANDS.filter((b) => b.kind === "period");
const HOUR_MARKS = Array.from({ length: 12 }, (_, i) => (9 + i) * 60);

function minuteOfDay(timestamp: number): number {
  const d = new Date(timestamp);
  return d.getHours() * 60 + d.getMinutes();
}

function clampMinute(minute: number): number {
  return Math.min(Math.max(minute, DAY_START), DAY_END);
}

function dayFraction(minute: number): number {
  return (clampMinute(minute) - DAY_START) / (DAY_END - DAY_START);
}

/** y for a minute on the canvas. */
function topFor(minute: number, extraPx = 0): string {
  return `calc(100% * ${dayFraction(minute).toFixed(4)} + ${extraPx}px)`;
}

function heightBetween(startMinute: number, endMinute: number): string {
  const f = Math.max(0, dayFraction(endMinute) - dayFraction(startMinute));
  return `calc(100% * ${f.toFixed(4)})`;
}

function overlapsSlot(slot: TimelineBand, start: number, end: number): boolean {
  return start < slot.end && end > slot.start;
}

function periodLabelFor(start: number, end: number): string | null {
  const slot = PERIODS.find((s) => overlapsSlot(s, start, end));
  return slot ? `P${slot.period}` : null;
}

function DayTimeline({
  date,
  lessons,
  onSelect,
}: {
  date: string;
  lessons: Lesson[];
  onSelect: (lesson: Lesson) => void;
}) {
  const isToday = date === todayIsoDate();
  const [nowMinute, setNowMinute] = useState(() => minuteOfDay(Date.now()));
  useEffect(() => {
    if (!isToday) return;
    const t = setInterval(() => setNowMinute(minuteOfDay(Date.now())), 30_000);
    return () => clearInterval(t);
  }, [isToday]);

  const visible = lessons.filter(
    (l) => clampMinute(minuteOfDay(l.endsAt)) > clampMinute(minuteOfDay(l.startsAt)),
  );
  const freeSlots = PERIODS.filter(
    (slot) =>
      !lessons.some((l) => overlapsSlot(slot, minuteOfDay(l.startsAt), minuteOfDay(l.endsAt))),
  );
  const showNow = isToday && nowMinute >= DAY_START && nowMinute <= DAY_END;

  return (
    <div className="timeline">
      <div className="timeline__hours" aria-hidden="true">
        <span className="timeline__allday">All-day</span>
        {HOUR_MARKS.map((minute) => (
          <span
            key={minute}
            className="timeline__hour"
            style={{ top: topFor(minute, -6) }}
          >
            {String(Math.floor(minute / 60)).padStart(2, "0")}:00
          </span>
        ))}
      </div>

      <div className="timeline__canvas">
        {/* No exam strip: HOney has no exams feature, and the app must not
            assert "no exams" it cannot know (review 2026-09-01, finding 7).
            Matches iOS, where the strip is a deliberate correct absence. */}
        {BANDS.map((band) => (
          <div
            key={band.id}
            className={
              band.kind === "break"
                ? "timeline__band timeline__band--break"
                : band.period! % 2 === 0
                  ? "timeline__band timeline__band--even"
                  : "timeline__band timeline__band--odd"
            }
            style={{ top: topFor(band.start), height: heightBetween(band.start, band.end) }}
          />
        ))}

        {HOUR_MARKS.map((minute) => (
          <div key={minute} className="timeline__gridline" style={{ top: topFor(minute) }} />
        ))}

        {freeSlots.map((slot) => (
          <div key={slot.id} className="timeline__ghost" style={{ top: topFor(slot.start, 7) }}>
            <span className="timeline__ghost-period">P{slot.period}</span>
            <span className="timeline__ghost-free">Free</span>
          </div>
        ))}

        {BANDS.filter((b) => b.kind === "break").map((band) => (
          <div key={band.id} className="timeline__ghost" style={{ top: topFor(band.start, 7) }}>
            <LeafGlyph />
            <span className="timeline__ghost-break">{band.label}</span>
          </div>
        ))}

        {visible.map((lesson) => {
          const start = minuteOfDay(lesson.startsAt);
          const end = minuteOfDay(lesson.endsAt);
          const compact = end - start < 45;
          const period = periodLabelFor(start, end);
          return (
            <button
              key={lesson.id}
              className={compact ? "lesson-block lesson-block--compact" : "lesson-block"}
              style={{ top: topFor(start), height: heightBetween(start, end) }}
              onClick={() => onSelect(lesson)}
            >
              <span className="lesson-block__body">
                <span className="lesson-block__row">
                  <span className="lesson-block__subject">{lesson.subjectName}</span>
                  {lesson.roomName && (
                    <span className="lesson-block__room">{lesson.roomName}</span>
                  )}
                </span>
                <span className="lesson-block__meta">
                  {period && <strong>{period} · </strong>}
                  {formatTime(lesson.startsAt)}–{formatTime(lesson.endsAt)}
                </span>
              </span>
            </button>
          );
        })}

        {visible.length === 0 && (
          <div className="timeline__empty">
            <CalendarGlyph />
            <span>No lessons today</span>
          </div>
        )}

        {showNow && <div className="timeline__now" style={{ top: topFor(nowMinute, -4) }} />}
      </div>
    </div>
  );
}

function LeafGlyph() {
  return (
    <svg viewBox="0 0 12 12" fill="currentColor" aria-hidden="true">
      <path d="M10.5 1.5C6 1.5 2.6 3.4 2.1 7c-.3 2 .7 3.5 2.4 3.5 3.8 0 6-4.3 6-9zM2.5 10.8c.9-2.8 2.6-5 5.3-6.6-2.1 2-3.6 4.3-4.3 6.9z" />
    </svg>
  );
}

function CalendarGlyph() {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <rect x="3.5" y="5" width="17" height="15.5" rx="2" />
      <path d="M3.5 9.5h17" />
      <path d="M8 2.75V6M16 2.75V6" />
    </svg>
  );
}

function LessonDetail({ lesson, onClose }: { lesson: Lesson; onClose: () => void }) {
  return (
    <Modal title={lesson.subjectName} onClose={onClose}>
      <dl className="kv">
        <dt>Time</dt>
        <dd>
          {formatTime(lesson.startsAt)}–{formatTime(lesson.endsAt)}
        </dd>
        {lesson.topicName && (
          <>
            <dt>Topic</dt>
            <dd>{lesson.topicName}</dd>
          </>
        )}
        {lesson.teacherName && (
          <>
            <dt>Teacher</dt>
            <dd>{lesson.teacherName}</dd>
          </>
        )}
        {lesson.courseName && (
          <>
            <dt>Course</dt>
            <dd>{lesson.courseName}</dd>
          </>
        )}
        {lesson.roomName && (
          <>
            <dt>Room</dt>
            <dd>{lesson.roomName}</dd>
          </>
        )}
      </dl>
      <div className="modal__actions">
        {lesson.teacherId && (
          <Link className="btn btn--ghost" to={`/experiences/teacher/${lesson.teacherId}`}>
            View teacher experiences
          </Link>
        )}
        {lesson.courseId && (
          <Link className="btn btn--ghost" to={`/experiences/course/${lesson.courseId}`}>
            View course experiences
          </Link>
        )}
        <Link className="btn btn--primary" to={`/experiences/compose?lessonId=${lesson.id}`}>
          Share experience
        </Link>
      </div>
    </Modal>
  );
}
