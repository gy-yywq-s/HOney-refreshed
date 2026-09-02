// The Week overview (timetable addendum v1.1): a school-period MATRIX, not
// a shrunken calendar. Columns are Mon–Fri, rows are the period catalog,
// breaks are one spanning separator, cells carry subject + room only. It
// answers "what is the shape of my week"; Day keeps the chronology. A
// <table> so screen readers get row/column headers for free.

import type { Lesson } from "../../api/types";
import { compactSubjectName, roomLabel } from "../../lib/displayNames";
import { BANDS, PERIODS, minuteLabel, minuteOfDay, overlapsSlot } from "../../lib/periodCatalog";
import { formatDayTitle, formatTime, shiftIsoDate } from "../../lib/format";
import { Skeleton } from "../../lib/motion";

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri"];

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

export function WeekView({ monday, days, loading, error, onRetry, onOpenDay, onSelect, today, now }: WeekViewProps) {
  const dates = WEEKDAYS.map((_, i) => shiftIsoDate(monday, i));
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
      <table className="week__table" aria-busy={loading || undefined}>
        <thead>
          <tr>
            <th scope="col" className="week__gutter">
              <span className="sr-only">Period</span>
            </th>
            {dates.map((date, i) => (
              <th key={date} scope="col" className={date === today ? "week__day week__day--today" : "week__day"}>
                <button type="button" className="week__daybtn" onClick={() => onOpenDay(date)} aria-label={`Open ${formatDayTitle(date)}`}>
                  <span className="week__dayname">{WEEKDAYS[i]}</span>
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
                <th scope="row" colSpan={6}>
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
                    first.subjectName,
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
                        <span className="week__subject">{compactSubjectName(first.subjectName)}</span>
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
                    <span className="entity-row__title">{lesson.subjectName}</span>
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
