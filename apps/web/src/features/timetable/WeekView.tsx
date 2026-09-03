// The Week overview (timetable addendum v1.1): a school-period MATRIX, not
// a shrunken calendar. Columns are Mon–Fri, rows are the period catalog,
// breaks are one spanning separator, cells carry subject + room only. It
// answers "what is the shape of my week"; Day keeps the chronology. A
// <table> so screen readers get row/column headers for free.

import type { Lesson } from "../../api/types";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { compactLessonTitle, lessonTitle, roomLabel } from "../../lib/displayNames";
import { BANDS, PERIODS, minuteLabel, minuteOfDay, overlapsSlot } from "../../lib/periodCatalog";
import { formatDayTitle, formatTime, shiftIsoDate } from "../../lib/format";
import { Skeleton } from "../../lib/motion";

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const COLUMN_PX = 66; // the regular column; more columns scroll sideways, never squeeze

export interface WeekViewProps {
  /** The Monday of the week shown. */
  monday: string;
  /** Lessons per ISO date; null while loading. */
  days: Record<string, Lesson[]> | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
  onOpenDay: (date: string) => void;
  onSelect: (lesson: Lesson) => void;
  today: string;
  now: number;
}

/** Phone columns (≤430px) take the short tier; wider columns the compact name. */
function usePhoneColumns(): boolean {
  const [narrow, setNarrow] = useState(() => typeof window !== "undefined" && window.matchMedia("(max-width: 430px)").matches);
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 430px)");
    const on = () => setNarrow(mq.matches);
    mq.addEventListener("change", on);
    return () => mq.removeEventListener("change", on);
  }, []);
  return narrow;
}

/**
 * The matrix fills the visible height (Gary 2026-09-03: 周课表稍微填满一点屏幕):
 * the period rows share whatever the scroll region leaves below the day
 * header, measured on this device — never a per-model guess — and clamped
 * so a small phone keeps readable cells and a tall one does not balloon.
 */
const CELL_MIN = 56;
const CELL_MAX = 104;
function useFillingCells(tableRef: React.RefObject<HTMLTableElement | null>): number | null {
  const [cell, setCell] = useState<number | null>(null);
  useLayoutEffect(() => {
    const table = tableRef.current;
    const scroller = table?.closest<HTMLElement>(".main");
    if (!table || !scroller) return;
    const measure = () => {
      const s = scroller.getBoundingClientRect();
      const padBottom = parseFloat(getComputedStyle(scroller).paddingBottom) || 0;
      const top = table.getBoundingClientRect().top - s.top + scroller.scrollTop;
      const available = scroller.clientHeight - padBottom - top;
      const head = table.tHead?.getBoundingClientRect().height ?? 0;
      const breaks = Array.from(table.querySelectorAll<HTMLElement>(".week__break")).reduce((n, r) => n + r.getBoundingClientRect().height, 0);
      const periods = table.querySelectorAll(".week__row").length || 1;
      const next = Math.floor((available - head - breaks) / periods);
      setCell(Math.max(CELL_MIN, Math.min(CELL_MAX, next)));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(scroller);
    window.addEventListener("resize", measure);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", measure);
    };
  }, [tableRef]);
  return cell;
}

export function WeekView({ monday, days, loading, error, onRetry, onOpenDay, onSelect, today, now }: WeekViewProps) {
  const phone = usePhoneColumns();
  const tableRef = useRef<HTMLTableElement>(null);
  const cell = useFillingCells(tableRef);
  const cellName = (lesson: Lesson) => compactLessonTitle(lesson, phone);
  // Mon–Fri always; Saturday/Sunday only when the imported week has a lesson
  // there (Gary 2026-09-02) — then the matrix scrolls sideways.
  const all = WEEKDAYS.map((_, i) => shiftIsoDate(monday, i));
  const dates = all.filter((d, i) => i < 5 || ((days?.[d]?.length ?? 0) > 0));
  const dayIndex = (d: string) => all.indexOf(d);
  const unplaced: { date: string; lesson: Lesson }[] = [];
  const grid = new Map<string, Lesson[]>(); // `${date}|${bandId}` → lessons
  if (days) {
    for (const date of dates) {
      for (const l of days[date] ?? []) {
        const s = minuteOfDay(l.startsAt);
        const e = minuteOfDay(l.endsAt);
        const hits = PERIODS.filter((p) => overlapsSlot(p, s, e));
        if (hits.length === 0) unplaced.push({ date, lesson: l });
        for (const p of hits) {
          const k = `${date}|${p.id}`;
          grid.set(k, [...(grid.get(k) ?? []), l]);
        }
      }
    }
  }
  const isNow = (l: Lesson) => now >= l.startsAt && now < l.endsAt;

  return (
    <div className="week">
      {error && !loading && (
        <div role="alert" className="banner banner--danger">
          <span>{error}</span>
          <button className="btn btn--ghost btn--small" onClick={onRetry}>
            Try again
          </button>
        </div>
      )}
      <table
        ref={tableRef}
        className="week__table"
        aria-busy={loading || undefined}
        style={{
          ...(dates.length > 5 ? { minWidth: 32 + dates.length * COLUMN_PX } : {}),
          ...(cell ? ({ "--week-cell": `${cell}px` } as React.CSSProperties) : {}),
        }}
      >
        <thead>
          <tr>
            <th scope="col" className="week__gutter">
              <span className="sr-only">Period</span>
            </th>
            {dates.map((date) => (
              <th key={date} scope="col" className={date === today ? "week__day week__day--today" : "week__day"}>
                <button type="button" className="week__daybtn" onClick={() => onOpenDay(date)} aria-label={`Open ${formatDayTitle(date)}`}>
                  <span className="week__dayname">{WEEKDAYS[dayIndex(date)]}</span>
                  <span className="week__daynum">{Number(date.slice(8, 10))}</span>
                </button>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {BANDS.map((band) =>
            band.kind === "break" ? (
              <tr key={band.id} className="week__break">
                <th scope="row" colSpan={dates.length + 1}>
                  <span>
                    {band.label?.replace(" Break", "")} · {minuteLabel(band.start)}–{minuteLabel(band.end)}
                  </span>
                </th>
              </tr>
            ) : (
              <tr key={band.id} className="week__row">
                <th scope="row" className="week__gutter">
                  <span className="week__period">P{band.period}</span>
                  <span className="week__start">{minuteLabel(band.start)}</span>
                </th>
                {dates.map((date) => {
                  const cellLessons = grid.get(`${date}|${band.id}`) ?? [];
                  const first = cellLessons[0];
                  const todayCol = date === today;
                  if (!days) {
                    return (
                      <td key={date} className={todayCol ? "week__cell week__cell--today" : "week__cell"}>
                        {loading && <Skeleton lines={1} />}
                      </td>
                    );
                  }
                  if (!first) {
                    return (
                      <td key={date} className={todayCol ? "week__cell week__cell--free week__cell--today" : "week__cell week__cell--free"}>
                        <span className="sr-only">{`${formatDayTitle(date)}, Period ${band.period}, free.`}</span>
                      </td>
                    );
                  }
                  const label = [
                    `${formatDayTitle(date)}, Period ${band.period}`,
                    lessonTitle(first),
                    `${formatTime(first.startsAt)} to ${formatTime(first.endsAt)}`,
                    first.teacherName,
                    roomLabel(first.roomName),
                    cellLessons.length > 1 ? `and ${cellLessons.length - 1} more` : null,
                  ]
                    .filter(Boolean)
                    .join(", ");
                  const cls = [
                    "week__cell",
                    "week__cell--lesson",
                    todayCol ? "week__cell--today" : "",
                    isNow(first) ? "week__cell--now" : "",
                  ]
                    .filter(Boolean)
                    .join(" ");
                  return (
                    <td key={date} className={cls}>
                      <button type="button" className="week__lesson" onClick={() => onSelect(first)} aria-label={label}>
                        <span className="week__subject">{cellName(first)}</span>
                        {first.roomName && <span className="week__room">{first.roomName}</span>}
                        {cellLessons.length > 1 && <span className="week__more">+{cellLessons.length - 1}</span>}
                      </button>
                    </td>
                  );
                })}
              </tr>
            ),
          )}
        </tbody>
      </table>
      {unplaced.length > 0 && (
        <section className="week__other" aria-label="Outside the school periods">
          <h2 className="overline">Outside the school periods</h2>
          <ul className="entity-list">
            {unplaced.map(({ date, lesson }) => (
              <li key={lesson.id}>
                <button type="button" className="entity-row week__otherrow" onClick={() => onSelect(lesson)}>
                  <span className="entity-row__main">
                    <span className="entity-row__title">{lessonTitle(lesson)}</span>
                    <span className="caption">
                      {[formatDayTitle(date), `${formatTime(lesson.startsAt)}–${formatTime(lesson.endsAt)}`, roomLabel(lesson.roomName)]
                        .filter(Boolean)
                        .join(" · ")}
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
