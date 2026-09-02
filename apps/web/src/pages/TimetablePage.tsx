// Scroll model: FRAMED_SCROLL (§16.14.7) — sticky date nav frame; the day timeline scrolls.
import { Skeleton } from "../lib/motion";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import type { Lesson, SyncResponse } from "../api/types";
import { Modal } from "../components/Modal";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { PullToHistory } from "../components/PullToHistory";
import { useSyncHandler } from "../lib/refresh";
import { apiCache, useApi } from "../lib/useApi";
import { useRetryFocus } from "../lib/useRetryFocus";
import { parseCourseName, roomLabel } from "../lib/displayNames";
import { BANDS, PERIODS, minuteOfDay, overlapsSlot, periodLabelFor } from "../lib/periodCatalog";
import { WeekView } from "../features/timetable/WeekView";
import {
  formatDayTitle,
  formatTime,
  shiftIsoDate,
  timeAgo,
  todayIsoDate,
  formatShortDate,
  mondayOf,
  formatWeekRange,
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
  const { data, error, loading, reload } = useApi(() => api.timetable(date), [date], `timetable:${date}`);
  const [selected, setSelected] = useState<Lesson | null>(null);
  const closeLesson = useCallback(() => setSelected(null), []);
  const pickerRef = useRef<HTMLInputElement>(null);
  // Day | Week (addendum v1.1 §3): Day is the default; Week is kept while the
  // student works in the Timetable this session (never a cold-launch default).
  // ?view=week deep-links Week; a ?date= link without ?view= means Day.
  const [view, setView] = useState<"day" | "week">(() => {
    const v = searchParams.get("view");
    if (v === "week") return "week";
    if (v === "day" || searchParams.get("date")) return "day";
    try {
      return sessionStorage.getItem("honey.timetable.view") === "week" ? "week" : "day";
    } catch {
      return "day";
    }
  });
  useEffect(() => {
    try {
      sessionStorage.setItem("honey.timetable.view", view);
    } catch {
      /* ignore */
    }
  }, [view]);
  const monday = mondayOf(date);
  const week = useApi(
    () => (view === "week" ? api.timetableRange(monday, shiftIsoDate(monday, 6)) : Promise.resolve(null)),
    [view, monday],
    view === "week" ? `timetable:week:${monday}` : undefined,
  );
  const weekDays = useMemo(() => {
    if (!week.data) return null;
    const map: Record<string, Lesson[]> = {};
    for (const d of week.data.days) map[d.date] = d.lessons;
    return map;
  }, [week.data]);
  // The bar names the days the matrix shows: Mon–Fri, or through the weekend
  // day that has lessons.
  const weekEnd = weekDays
    ? (weekDays[shiftIsoDate(monday, 6)]?.length ? 6 : weekDays[shiftIsoDate(monday, 5)]?.length ? 5 : 4)
    : 4;
  // The address bar names the day shown, after every change (r8): a copied
  // link means what the page shows, an impossible ?date= is replaced.
  useEffect(() => {
    // Compare against the address bar itself (React Router never re-reads a
    // replaceState). Bare /timetable stays bare while showing today: a copied
    // "today" link must not pin yesterday tomorrow (recorded decision).
    const params = new URLSearchParams(window.location.search);
    const current = params.get("date");
    const currentView = params.get("view");
    if (current === null && currentView === null && date === todayIsoDate() && view === "day") return;
    if (current !== date || (currentView ?? "day") !== view) {
      const next = new URLSearchParams({ date });
      if (view === "week") next.set("view", "week");
      window.history.replaceState(null, "", `/timetable?${next}`);
    }
  }, [date, view]);
  const [syncBusy, setSyncBusy] = useState(false);
  const [syncFeedback, setSyncFeedback] = useState<SyncFeedback | null>(null);
  const [showReconnect, setShowReconnect] = useState(false);
  const landing = useRetryFocus<HTMLDivElement>(loading || week.loading);
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
        <div className="daynav__modes" role="tablist" aria-label="Timetable view">
          <button type="button" role="tab" aria-selected={view === "day"} className="daynav__mode" onClick={() => setView("day")}>
            Day
          </button>
          <button type="button" role="tab" aria-selected={view === "week"} className="daynav__mode" onClick={() => setView("week")}>
            Week
          </button>
        </div>
        <div className="daynav__stepper" role="group" aria-label={view === "week" ? "Choose a week" : "Choose a day"}>
          <button
            className="daynav__arrow"
            aria-label={view === "week" ? "Previous week" : "Previous day"}
            onClick={() => setDate((d) => shiftIsoDate(d, view === "week" ? -7 : -1))}
          >
            &lsaquo;
          </button>
          {/* The date is the page heading and the picker in one: the native
              <input type="date"> sits invisibly over the text, so a tap or
              a click opens the platform's own calendar (iOS included). */}
          <h1 className="daynav__date">
            {/* One ringed Tab stop (the button); the native input stays
                under the finger for taps but out of the Tab order (r10). */}
            <button
              type="button"
              className="daynav__datebtn"
              aria-label={view === "week" ? `Pick a week (${formatWeekRange(monday, weekEnd)})` : `Pick a date (${formatDayTitle(date)})`}
              onClick={() => {
                const el = pickerRef.current;
                if (!el) return;
                try {
                  el.showPicker?.();
                } catch {
                  el.focus();
                }
              }}
            >
              <span className="daynav__date-long">{view === "week" ? formatWeekRange(monday, weekEnd) : formatDayTitle(date)}</span>
              <span className="daynav__date-short" aria-hidden="true">
                {view === "week" ? formatWeekRange(monday, weekEnd) : formatStepperDate(date)}
              </span>
              <svg className="daynav__caret" viewBox="0 0 12 12" width="12" height="12" aria-hidden="true">
                <path d="M2.5 4.5 6 8l3.5-3.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </button>
            <input
              ref={pickerRef}
              className="daynav__picker"
              type="date"
              tabIndex={-1}
              aria-hidden="true"
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
            aria-label={view === "week" ? "Next week" : "Next day"}
            onClick={() => setDate((d) => shiftIsoDate(d, view === "week" ? 7 : 1))}
          >
            &rsaquo;
          </button>
        </div>
        {(view === "week" ? mondayOf(todayIsoDate()) !== monday : !isToday) && (
          <button className="btn btn--ghost btn--small daynav__today" onClick={() => setDate(todayIsoDate())}>
            {view === "week" ? "This week" : "Back to today"}
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

      <div ref={landing.ref} tabIndex={-1} className="focus-landing" role="region" aria-label={view === "week" ? "Week overview" : "Day timeline"}>

      {view === "week" ? (
        <WeekView
          monday={monday}
          days={weekDays}
          loading={week.loading}
          error={week.error}
          onRetry={() => {
            landing.arm();
            week.reload();
          }}
          onOpenDay={(d) => {
            setDate(d);
            setView("day");
          }}
          onSelect={(lesson) => setSelected(lesson)}
          today={todayIsoDate()}
          now={Date.now()}
        />
      ) : loading ? (
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
      {selected && (
        <LessonDetail
          lesson={selected}
          onClose={closeLesson}
          {...(view === "week"
            ? {
                onOpenDay: () => {
                  const d = new Date(selected.startsAt).toLocaleDateString("en-CA");
                  setSelected(null);
                  setDate(d);
                  setView("day");
                },
              }
            : {})}
        />
      )}
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

// The period catalog (P1–P6, Lunch, Dinner) lives in lib/periodCatalog.ts,
// shared with the Week overview.


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
      const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
      if (!el || !owner) return;
      // Set scrollTop directly: unlike scrollIntoView() it never moves the
      // sequential-focus start point, so Tab 1 stays the skip link (r10).
      const margin = 100; // heading + bar stay in view above block 1
      const top = el.getBoundingClientRect().top - owner.getBoundingClientRect().top + owner.scrollTop - margin;
      const prev = owner.style.scrollBehavior;
      owner.style.scrollBehavior = "auto";
      owner.scrollTop = Math.max(0, top);
      owner.style.scrollBehavior = prev;
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

function LessonDetail({
  lesson,
  onClose,
  onOpenDay,
}: {
  lesson: Lesson;
  onClose: () => void;
  /** From the Week overview: the semantic-zoom step down to the day. */
  onOpenDay?: () => void;
}) {
  const course = lesson.courseName ? parseCourseName(lesson.courseName, lesson.teacherName) : null;
  const extra = course && course.meta ? course.meta : null;
  return (
    <Modal title={lesson.subjectName} onClose={onClose} describedBy="lesson-dialog-body">
      <p className="sr-only" id="lesson-dialog-body">
        {[
          `${formatShortDate(lesson.startsAt)}, ${formatTime(lesson.startsAt)} to ${formatTime(lesson.endsAt)}`,
          lesson.teacherName ? `with ${lesson.teacherName}` : null,
          lesson.roomName ? `in ${roomLabel(lesson.roomName)}` : null,
        ]
          .filter(Boolean)
          .join(", ")}
        .
      </p>
      {/* Core context first (§16.1): when, then who and where. */}
      <div className="lesson-facts" aria-hidden="true">
        <div className="lesson-facts__line lesson-facts__line--time">
          {formatShortDate(lesson.startsAt)} · {formatTime(lesson.startsAt)}–{formatTime(lesson.endsAt)}
        </div>
        {(lesson.teacherName || lesson.roomName) && (
          <div className="lesson-facts__line">
            {[lesson.teacherName, roomLabel(lesson.roomName)].filter(Boolean).join(" · ")}
          </div>
        )}
      </div>
      <div className="modal__actions">
        {onOpenDay && (
          <button type="button" className="btn btn--ghost" onClick={onOpenDay}>
            Open this day
          </button>
        )}
        <Link className="btn btn--primary" to={`/experiences/compose?lessonId=${lesson.id}`}>
          Share what this was like
        </Link>
        {lesson.teacherId && (
          <Link className="btn btn--ghost" to={`/experiences/teacher/${lesson.teacherId}`}>
            Experiences with {lesson.teacherName ?? "this teacher"}
          </Link>
        )}
        {lesson.courseId && (
          <Link className="btn btn--ghost" to={`/experiences/course/${lesson.courseId}`}>
            Experiences from this course
          </Link>
        )}
      </div>
      {(extra || (lesson.topicName && lesson.topicName !== lesson.subjectName)) && (
        <details className="disclosure">
          <summary>More lesson details</summary>
          <dl className="kv">
            {lesson.topicName && lesson.topicName !== lesson.subjectName && (
              <>
                <dt>Topic</dt>
                <dd>{lesson.topicName}</dd>
              </>
            )}
            {extra && (
              <>
                <dt>Course</dt>
                <dd>{extra}</dd>
              </>
            )}
          </dl>
        </details>
      )}
    </Modal>
  );
}
