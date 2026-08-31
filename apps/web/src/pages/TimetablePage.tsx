import { useState } from "react";
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

      <h1 className="page-title">{formatDayHeading(date)}</h1>

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
          {!data || data.lessons.length === 0 ? (
            <p className="card empty">No lessons on this day.</p>
          ) : (
            <ul className="lesson-list">
              {data.lessons.map((lesson) => (
                <li key={lesson.id}>
                  <button className="lesson-block" onClick={() => setSelected(lesson)}>
                    <span className="lesson-block__time">
                      {formatTime(lesson.startsAt)}
                      <br />
                      {formatTime(lesson.endsAt)}
                    </span>
                    <span className="lesson-block__body">
                      <span className="lesson-block__subject">{lesson.subjectName}</span>
                      {lesson.topicName && <span className="muted">{lesson.topicName}</span>}
                      <span className="caption">
                        {[lesson.teacherName, lesson.roomName].filter(Boolean).join(" · ")}
                      </span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
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
