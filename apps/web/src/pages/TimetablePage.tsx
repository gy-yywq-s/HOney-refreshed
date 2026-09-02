// Scroll model: FRAMED_SCROLL (§16.14.7) — sticky date nav frame; the day timeline scrolls.
import { Skeleton } from "../lib/motion";
import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import type { Lesson, SyncResponse } from "../api/types";
import { Modal } from "../components/Modal";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { PullToHistory } from "../components/PullToHistory";
import { useSyncHandler } from "../lib/refresh";
import { apiCache, useApi } from "../lib/useApi";
import { useRetryFocus } from "../lib/useRetryFocus";
import {
  formatDayTitle,
  formatTime,
  shiftIsoDate,
  timeAgo,
  todayIsoDate,
} from "../lib/format";

type SyncFeedback = { kind: "result"; result: SyncResponse } | { kind: "error"; message: string };

/** Compact day for the stepper, in the same locale the heading uses. */
function formatStepperDate(isoDate: string): string {
  const [y, m, d] = isoDate.split("-").map(Number);
  const day = new Date(y!, (m ?? 1) - 1, d ?? 1);
  return day.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" });
}

export function TimetablePage() {
  const [searchParams] = useSearchParams();
  const [date, setDate] = useState(() => {
    const q = searchParams.get("date");
    // A real calendar date only (2026-13-45 is not a day).
    if (q && /^\d{4}-\d{2}-\d{2}$/.test(q)) {
      const [y, m, d] = q.split("-").map(Number);
      const dt = new Date(y!, m! - 1, d!);
      if (dt.getFullYear() === y && dt.getMonth() === m! - 1 && dt.getDate() === d) return q;
    }
    return todayIsoDate();
  });
  // The address bar names the day shown, after every change (r8): a copied
  // link means what the page shows, an impossible ?date= is replaced.
  useEffect(() => {
    // Compare against the address bar itself (React Router never re-reads a
    // replaceState). Bare /timetable stays bare while showing today: a copied
    // "today" link must not pin yesterday tomorrow (recorded decision).
    const current = new URLSearchParams(window.location.search).get("date");
    if (current === null && date === todayIsoDate()) return;
    if (current !== date) window.history.replaceState(null, "", `/timetable?date=${date}`);
  }, [date]);
  const { data, error, loading, reload } = useApi(() => api.timetable(date), [date], `timetable:${date}`);
  const [selected, setSelected] = useState<Lesson | null>(null);
  const closeLesson = useCallback(() => setSelected(null), []);
  const [syncBusy, setSyncBusy] = useState(false);
  const [syncFeedback, setSyncFeedback] = useState<SyncFeedback | null>(null);
  const [showReconnect, setShowReconnect] = useState(false);
  const landing = useRetryFocus<HTMLDivElement>(loading);
  // Landing contract: the FIRST settle (success or error) of a date — cold
  // load, re-entry or a date step — lands once; every later arrival for the
  // same date (a retry, a refresh) must not scroll.
  // The render right after a date change still carries the previous
  // date's loading=false, so "settled" is only trusted once this date has
  // been seen loading (or it is the date the screen mounted with).
  // Landing contract (r9): the first settled render of a date — cold load,
  // re-entry or a date step, cached or not — lands once; a retry or a
  // refresh never scrolls. "Settled" means the lessons object on screen is
  // not the previous date's (the render right after a date change still
  // carries the old data).
  const settledDates = useRef(new Set<string>());
  const lessonsAtChange = useRef<{ date: string; lessons: unknown }>({ date, lessons: data?.lessons });
  if (lessonsAtChange.current.date !== date) lessonsAtChange.current = { date, lessons: data?.lessons };
  const fresh = !loading && data !== null && data.lessons !== lessonsAtChange.current.lessons;
  const coldLanding = (fresh || (data !== null && !loading && settledDates.current.size === 0)) && !settledDates.current.has(date);
  useEffect(() => {
    if (coldLanding) settledDates.current.add(date);
  }, [coldLanding, date]);

  async function runSync() {
    setSyncBusy(true);
    setSyncFeedback(null);
    try {
      // Seamless: on portal expiry, silently re-login if this device is
      // authorized, so a routine 24h expiry never dead-ends at a prompt.
      const { result } = await api.syncSeamless();
      setSyncFeedback({ kind: "result", result });
      if (result.status === "ok") {
        apiCache.invalidate("timetable");
        apiCache.invalidate("next-lesson");
        apiCache.invalidate("history");
        apiCache.invalidate("directory");
        reload();
      }
    } catch (err) {
      setSyncFeedback({ kind: "error", message: describeApiError(err) });
    } finally {
      setSyncBusy(false);
    }
  }

  const isToday = date === todayIsoDate();
  // The pull's second stage (phones) is this screen's own sync.
  useSyncHandler(() => {
    if (!syncBusy) void runSync();
  });

  return (
    <div className="timetable-screen">
      <header className="daynav">
        <div className="daynav__stepper" role="group" aria-label="Choose a day">
          <button
            className="daynav__arrow"
            aria-label="Previous day"
            onClick={() => setDate((d) => shiftIsoDate(d, -1))}
          >
            &lsaquo;
          </button>
          {/* The date is the page heading and the picker in one: the native
              <input type="date"> sits invisibly over the text, so a tap or
              a click opens the platform's own calendar (iOS included). */}
          <h1 className="daynav__date">
            <span className="daynav__date-long">{formatDayTitle(date)}</span>
            <span className="daynav__date-short" aria-hidden="true">
              {formatStepperDate(date)}
            </span>
            <svg className="daynav__caret" viewBox="0 0 12 12" width="12" height="12" aria-hidden="true">
              <path d="M2.5 4.5 6 8l3.5-3.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            <input
              className="daynav__picker"
              type="date"
              aria-label={`Pick a date (${formatDayTitle(date)})`}
              value={date}
              onClick={(e) => {
                // Desktop browsers open the calendar only from their own
                // icon; ask for it directly. Platforms that opened it on the
                // tap already (iOS) throw here, which is fine.
                try {
                  e.currentTarget.showPicker?.();
                } catch {
                  /* picker already open or unsupported */
                }
              }}
              onChange={(e) => {
                if (e.target.value) setDate(e.target.value);
              }}
            />
          </h1>
          <button
            className="daynav__arrow"
            aria-label="Next day"
            onClick={() => setDate((d) => shiftIsoDate(d, 1))}
          >
            &rsaquo;
          </button>
        </div>
        {!isToday && (
          <button className="btn btn--ghost btn--small daynav__today" onClick={() => setDate(todayIsoDate())}>
            Back to today
          </button>
        )}
        {/* Desktop only: the phone answers these with gestures — pull down
            twice (refresh, then sync), pull up at the end for History. A
            keyboard on a phone still reaches History through the sr link. */}
        <div className="daynav__row">
          <span className="caption daynav__state">
            {data?.lastSyncedAt ? `Synced ${timeAgo(data.lastSyncedAt)}` : ""}
          </span>
          <span className="daynav__spacer" />
          <Link className="btn btn--ghost btn--small" to="/history">
            History
          </Link>
          <button
            className="btn btn--primary btn--small"
            onClick={() => void runSync()}
            disabled={syncBusy}
          >
            {syncBusy ? "Syncing…" : "Sync now"}
          </button>
        </div>
        <Link className="daynav__history-sr" to="/history">
          History
        </Link>
      </header>
      <PullToHistory />

      {syncFeedback?.kind === "error" && (
        <div role="alert" className="banner banner--danger">{syncFeedback.message}</div>
      )}
      {syncFeedback?.kind === "result" && syncFeedback.result.status === "ok" && (
        <div role="status" className="banner banner--success">
          Synced {syncFeedback.result.lessons} lessons from the school portal.
        </div>
      )}
      {syncFeedback?.kind === "result" &&
        syncFeedback.result.status === "portal_reconnect_required" && (
          <div role="status" className="banner banner--warning">
            <span>HOney lost its connection to the school portal.</span>
            <button className="btn btn--ghost btn--small" onClick={() => setShowReconnect(true)}>
              Reconnect
            </button>
          </div>
        )}

      <div ref={landing.ref} tabIndex={-1} className="focus-landing" role="region" aria-label="Day timeline">

      {loading ? (
        <Skeleton lines={4} />
      ) : error ? (
        <div role="alert" className="banner banner--danger">
          <span>{error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); reload(); }}>
            Try again
          </button>
        </div>
      ) : (
        <DayTimeline
          date={date}
          lessons={data?.lessons ?? []}
          land={coldLanding}
          onSelect={(lesson) => setSelected(lesson)}
        />
      )}

      </div>
      {selected && <LessonDetail lesson={selected} onClose={closeLesson} />}
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

// The canvas covers the school day, 09:00–20:00, and widens to the hour
// whenever a lesson falls outside it (2026-09-02: 08:30 lessons exist in
// real data; a clipped block is not an option).
const DEFAULT_START = 9 * 60;
const DEFAULT_END = 20 * 60;
interface DayRange {
  start: number;
  end: number;
}

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

function minuteOfDay(timestamp: number): number {
  const d = new Date(timestamp);
  return d.getHours() * 60 + d.getMinutes();
}

function rangeFor(lessons: Lesson[]): DayRange {
  let start = DEFAULT_START;
  let end = DEFAULT_END;
  for (const l of lessons) {
    start = Math.min(start, Math.floor(minuteOfDay(l.startsAt) / 60) * 60);
    end = Math.max(end, Math.ceil(minuteOfDay(l.endsAt) / 60) * 60);
  }
  return { start, end };
}

/** Canvas geometry for one day range: y positions are fractions of the
 *  canvas height, so the canvas may be any height. */
function geometryFor(range: DayRange) {
  const clamp = (minute: number) => Math.min(Math.max(minute, range.start), range.end);
  const fraction = (minute: number) => (clamp(minute) - range.start) / (range.end - range.start);
  const topFor = (minute: number, extraPx = 0) =>
    `calc(100% * ${fraction(minute).toFixed(4)} + ${extraPx}px)`;
  const heightBetween = (startMinute: number, endMinute: number) =>
    `calc(100% * ${Math.max(0, fraction(endMinute) - fraction(startMinute)).toFixed(4)})`;
  const hourMarks: number[] = [];
  for (let m = range.start; m <= range.end; m += 60) hourMarks.push(m);
  return { clamp, topFor, heightBetween, hourMarks };
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
  land,
  onSelect,
}: {
  date: string;
  lessons: Lesson[];
  /** True only on the cold landing of a date (never after a retry). */
  land: boolean;
  onSelect: (lesson: Lesson) => void;
}) {
  const isToday = date === todayIsoDate();
  const range = rangeFor(lessons);
  const geo = geometryFor(range);
  const [nowMinute, setNowMinute] = useState(() => minuteOfDay(Date.now()));
  useEffect(() => {
    if (!isToday) return;
    const t = setInterval(() => setNowMinute(minuteOfDay(Date.now())), 30_000);
    return () => clearInterval(t);
  }, [isToday]);

  const visible = lessons.filter(
    (l) => geo.clamp(minuteOfDay(l.endsAt)) > geo.clamp(minuteOfDay(l.startsAt)),
  );
  const freeSlots = PERIODS.filter(
    (slot) =>
      !lessons.some((l) => overlapsSlot(slot, minuteOfDay(l.startsAt), minuteOfDay(l.endsAt))),
  );
  const showNow = isToday && nowMinute >= range.start && nowMinute <= range.end;
  // Compact heights (≤620px): the 620px canvas cannot fit above the fixed
  // nav, so land with the first lesson still ahead at the top of the scroll
  // owner instead of the 09:00 line. Proportions stay; the scroll starts
  // where the day does. Never on a normal-height screen.
  useEffect(() => {
    if (!land || window.innerHeight > 620 || visible.length === 0) return;
    // Always the FIRST lesson of the day: the heading and the note stay in
    // view in every clock state; later lessons are one swipe down.
    const first = visible[0]!;
    // After the shell's own route reset (a parent effect), and instantly:
    // the owner's smooth scroll-behavior must not animate the landing.
    requestAnimationFrame(() => {
      const el = document.querySelector<HTMLElement>(`[data-lesson="${first.id}"]`);
      el?.scrollIntoView({ block: "start", behavior: "instant" });
      // Reset the keyboard's starting point so Tab 1 is still the skip link.
      const skip = document.querySelector<HTMLElement>(".skip-link");
      skip?.focus({ preventScroll: true });
      skip?.blur();
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [date, visible.length, land]);

  return (
    <>
      {visible.length === 0 && (
        <p className="timeline__empty" role="status">
          <CalendarGlyph />
          <span>{isToday ? "No lessons today" : `No lessons on ${formatStepperDate(date)}`}</span>
        </p>
      )}
    <div className="timeline">
      <div className="timeline__hours" aria-hidden="true">
        {geo.hourMarks.map((minute) => (
          <span
            key={minute}
            className="timeline__hour"
            style={{ top: geo.topFor(minute, -6) }}
          >
            {String(Math.floor(minute / 60)).padStart(2, "0")}:00
          </span>
        ))}
      </div>

      <div className={visible.length === 0 ? "timeline__canvas timeline__canvas--empty" : "timeline__canvas"}>
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
            style={{ top: geo.topFor(band.start), height: geo.heightBetween(band.start, band.end) }}
          />
        ))}

        {geo.hourMarks.map((minute) => (
          <div key={minute} className="timeline__gridline" style={{ top: geo.topFor(minute) }} />
        ))}

        {freeSlots.map((slot) => (
          <div key={slot.id} className="timeline__ghost" style={{ top: geo.topFor(slot.start, 7) }}>
            <span className="timeline__ghost-period">P{slot.period}</span>
            <span className="timeline__ghost-free">Free</span>
          </div>
        ))}

        {BANDS.filter((b) => b.kind === "break").map((band) => (
          <div
            key={band.id}
            className="timeline__ghost timeline__ghost--break"
            style={{ top: geo.topFor(band.start, 7) }}
          >
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
              data-lesson={lesson.id}
              className={compact ? "lesson-block lesson-block--compact" : "lesson-block"}
              style={{ top: geo.topFor(start), height: geo.heightBetween(start, end) }}
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
                  {/* Teacher on the card face (Gary, 2026-09-01) — not detail-only. */}
                  {lesson.teacherName && (
                    <span className="lesson-block__teacher"> · {lesson.teacherName}</span>
                  )}
                </span>
              </span>
            </button>
          );
        })}


        {showNow && <div className="timeline__now" style={{ top: geo.topFor(nowMinute, -4) }} />}
      </div>
    </div>
    </>
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
    <Modal title={lesson.subjectName} onClose={onClose} describedBy="lesson-dialog-body">
      <p className="sr-only" id="lesson-dialog-body">
        {[
          `${formatTime(lesson.startsAt)} to ${formatTime(lesson.endsAt)}`,
          lesson.teacherName ? `with ${lesson.teacherName}` : null,
          lesson.roomName ? `in room ${lesson.roomName}` : null,
        ]
          .filter(Boolean)
          .join(", ")}
        .
      </p>
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
