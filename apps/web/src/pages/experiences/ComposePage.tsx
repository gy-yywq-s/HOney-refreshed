// /experiences/compose?lessonId= | ?entityKey= | ?noteId= — write an
// experience. Culture hints (spec §4, the Six Checks) appear as quiet
// placeholder/hint text, never as checkboxes. Publication is deliberate:
// the draft is preserved locally (audit §3.4), moderation runs synchronously
// as a preflight, and a `nudge` asks the user to choose before anything is
// published (audit §3.3) — nothing is ever auto-published.

import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, Lesson } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { formatShortDate, formatTime, formatRemaining } from "../../lib/format";
import { privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote } from "../../lib/ownershipKeys";
import { StarInput, describeCheckReasons } from "./shared";
import { useComposer } from "./useComposer";
import type { ComposerTarget } from "./useComposer";

// ONE stable prompt (review v3 §10.4): the composer is a quiet place to put
// an experience into words, not a rotating morality display. Boundaries
// appear only when a specific gate asks for something.
const COMPOSE_PROMPT = "What do you want to share about this experience?";
const COMPOSE_HELPER = "Specific context can help, but it is okay if what you have is only a feeling.";

export function ExperiencesComposePage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const lessonId = searchParams.get("lessonId");
  const entityKeyParam = searchParams.get("entityKey");
  const noteId = searchParams.get("noteId");

  const [note, setNote] = useState<PrivateNote | null>(null);
  const [saveBusy, setSaveBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!noteId) return;
    void privateNotes.get(noteId).then((n) => {
      if (n) setNote(n);
    });
  }, [noteId]);

  const effectiveLessonId = lessonId ?? note?.target.lessonId ?? null;
  const effectiveEntityKey = entityKeyParam ?? note?.target.entityKey ?? null;

  const history = useApi(
    () => (effectiveLessonId ? api.history({ limit: 200, order: "desc" }) : Promise.resolve(null)),
    [effectiveLessonId],
  );
  const entities = useApi(
    () => (effectiveEntityKey ? api.entities() : Promise.resolve(null)),
    [effectiveEntityKey],
  );

  const target = useMemo<ComposerTarget | null>(() => {
    if (effectiveLessonId) {
      const lesson: Lesson | undefined = history.data?.lessons.find((l) => l.id === effectiveLessonId);
      return {
        label: lesson ? lesson.subjectName : "A lesson from your history",
        ...(lesson
          ? {
              detail: [
                formatShortDate(lesson.startsAt),
                `${formatTime(lesson.startsAt)}–${formatTime(lesson.endsAt)}`,
                lesson.teacherName ?? "",
                lesson.roomName ?? "",
              ]
                .filter(Boolean)
                .join(" · "),
            }
          : {}),
        lessonId: effectiveLessonId,
        isDish: false,
      };
    }
    if (effectiveEntityKey) {
      const entity: EntityRef | undefined = entities.data?.entities.find(
        (e) => e.entity_key === effectiveEntityKey,
      );
      const type = effectiveEntityKey.split(":")[0] ?? "";
      return {
        label: entity?.name ?? effectiveEntityKey,
        detail: type === "room" ? "Place" : type === "dish" ? "Food" : "Teacher",
        entityKey: effectiveEntityKey,
        isDish: (entity?.type ?? type) === "dish",
      };
    }
    return null;
  }, [effectiveLessonId, effectiveEntityKey, history.data, entities.data]);

  const composer = useComposer(target);
  const { body, setBody, rating, setRating, status, notice } = composer;

  // Republishing a private note: seed the composer from the note's text.
  useEffect(() => {
    if (!note) return;
    setBody(note.body);
    setRating(note.rating);
    // Intentionally seed once when the note loads.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [note]);

  async function savePrivately() {
    if (saveBusy) return;
    setSaveBusy(true);
    setSaveError(null);
    try {
      await privateNotes.save({
        ...(note ? { id: note.id } : {}),
        body,
        rating: target?.isDish ? rating : null,
        target: {
          label: target ? [target.label, target.detail].filter(Boolean).join(" · ") : "No target",
          ...(target?.lessonId ? { lessonId: target.lessonId } : {}),
          ...(target?.entityKey ? { entityKey: target.entityKey } : {}),
          ...(target?.isDish ? { entityType: "dish" } : {}),
        },
      });
      setSaved(true);
    } catch {
      setSaveError("Could not save the note on this device.");
    } finally {
      setSaveBusy(false);
    }
  }

  if (status.kind === "published") {
    return (
      <div className="stack">
        <h1 className="page-title">Shared.</h1>
        <section className="card card--hero">
          <p>
            Your school identity is not shown with this Experience — it is stored without an author
            field, and the publish request carried no ordinary account identity.
          </p>
          <p className="text-3">
            This browser keeps a private control key so you can manage or revoke the post later.
            Keep it: what you wrote may still make you recognisable to people who know the
            situation.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/mine">
              Your notes &amp; posts
            </Link>
            <Link className="btn btn--ghost" to="/experiences">
              Back to Experiences
            </Link>
          </div>
        </section>
      </div>
    );
  }

  if (saved) {
    return (
      <div className="stack">
        <h1 className="page-title">Kept private</h1>
        <section className="card card--hero">
          <p>
            The note stays only on this device — it was never sent anywhere. You can edit, delete or
            publish it later from Your notes &amp; posts.
          </p>
          <p className="text-3">
            It is scrambled at rest so a casual look at browser storage won't read it, but the key
            sits on this device too — treat it as private-on-this-device, not encrypted-from-everyone.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/mine">
              Your notes &amp; posts
            </Link>
            <Link className="btn btn--ghost" to="/experiences">
              Back to Experiences
            </Link>
          </div>
        </section>
      </div>
    );
  }

  const busy = status.kind === "checking";
  const canAct = body.trim().length > 0 && !busy;

  return (
    <div className="stack">
      <div className="eyebrow">Compose</div>
      <h1 className="page-title">Share an experience</h1>

      {target ? (
        <section className="compose-target" aria-label="What this is about">
          <span className="eyebrow">About</span>
          <strong className="compose-target__label">{target.label}</strong>
          {target.detail && <span className="text-3">{target.detail}</span>}
        </section>
      ) : (
        <section className="card" aria-label="Pick a target">
          <p className="text-3">
            An experience is about one of your own lessons, or a teacher, place or dish.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/history?select=1">
              Pick a lesson from History
            </Link>
            <Link className="btn btn--ghost" to="/experiences">
              Browse teachers, places &amp; food
            </Link>
          </div>
        </section>
      )}

      {target && (
        <section className="stack">
          <div className="field">
            <label className="field__label" htmlFor="compose-body">
              {COMPOSE_PROMPT}
            </label>
            <textarea
              id="compose-body"
              className="input compose-textarea"
              rows={7}
              maxLength={5000}
              placeholder="Your own experience, in your own words"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              disabled={status.kind === "nudge"}
            />
            <span className="text-4 compose-hint">{COMPOSE_HELPER}</span>
          </div>

          {target.isDish && (
            <div className="field">
              <span className="field__label">Rating (dishes only — optional)</span>
              <StarInput value={rating} onChange={setRating} />
            </div>
          )}

          {notice && (
            <div className={`banner banner--${notice.tone === "danger" ? "danger" : "warning"}`}>
              <div>
                <p style={{ margin: 0 }}>{notice.text}</p>
                {describeCheckReasons(notice.reasons).length > 0 && (
                  <ul className="compose-reasons">
                    {describeCheckReasons(notice.reasons).map((r) => (
                      <li key={r}>{r}</li>
                    ))}
                  </ul>
                )}
                {notice.suggestKeepPrivate && (
                  <button
                    className="btn btn--ghost btn--small"
                    disabled={saveBusy}
                    onClick={() => void savePrivately()}
                  >
                    Keep as a private note
                  </button>
                )}
              </div>
            </div>
          )}
          {saveError && <div role="alert" className="banner banner--danger">{saveError}</div>}

          {status.kind === "nudge" ? (
            <NudgePreflight
              reasons={status.reasons}
              busy={busy}
              saveBusy={saveBusy}
              onPublish={() => void composer.publishAsIs()}
              onAddContext={composer.backToEditing}
              onKeepPrivate={() => void savePrivately()}
            />
          ) : status.kind === "cooldown" ? (
            <CooldownPanel
              retryAt={status.retryAt}
              onRecheck={() => void composer.recheckAfterCooldown()}
              onKeepPrivate={() => void savePrivately()}
              saveBusy={saveBusy}
            />
          ) : (
            <div className="card-actions compose-actions">
              <button
                className="btn btn--primary"
                disabled={!canAct}
                onClick={() => void composer.publish()}
              >
                {busy ? "Checking…" : "Share anonymously"}
              </button>
              <button
                className="btn btn--ghost"
                disabled={saveBusy || body.trim().length === 0 || busy}
                onClick={() => void savePrivately()}
              >
                {saveBusy ? "Saving…" : "Keep private"}
              </button>
              <button className="btn btn--ghost" disabled={busy} onClick={() => navigate(-1)}>
                Cancel
              </button>
            </div>
          )}

          <p className="text-4" style={{ marginBottom: 0 }}>
            Publishing runs a safety check first. Published posts carry no author ID; your only
            control is a key kept in this browser. Private notes never leave this device.{" "}
            <Link to="/settings">How privacy works</Link>
          </p>
        </section>
      )}
    </div>
  );
}

function NudgePreflight({
  reasons,
  busy,
  saveBusy,
  onPublish,
  onAddContext,
  onKeepPrivate,
}: {
  reasons: string[];
  busy: boolean;
  saveBusy: boolean;
  onPublish: () => void;
  onAddContext: () => void;
  onKeepPrivate: () => void;
}) {
  return (
    <section className="card nudge" aria-label="Before you publish">
      <span className="eyebrow">Before you share</span>
      <p style={{ marginTop: 0 }}>
        Would you like to add what led you to feel this way? A little context can help others
        understand. You can still share it as written.
      </p>
      {describeCheckReasons(reasons).length > 0 && (
        <ul className="compose-reasons">
          {describeCheckReasons(reasons).map((r) => (
            <li key={r}>{r}</li>
          ))}
        </ul>
      )}
      <div className="card-actions compose-actions">
        <button className="btn btn--primary" disabled={busy} onClick={onPublish}>
          {busy ? "Sharing…" : "Share as written"}
        </button>
        <button className="btn btn--ghost" disabled={busy} onClick={onAddContext}>
          Add context
        </button>
        <button className="btn btn--ghost" disabled={busy || saveBusy} onClick={onKeepPrivate}>
          Keep private
        </button>
      </div>
    </section>
  );
}

function CooldownPanel({
  retryAt,
  onRecheck,
  onKeepPrivate,
  saveBusy,
}: {
  retryAt: number;
  onRecheck: () => void;
  onKeepPrivate: () => void;
  saveBusy: boolean;
}) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(t);
  }, []);
  const remaining = retryAt - now;
  const ready = remaining <= 0;
  return (
    <section className="card nudge" aria-label="Cooling off">
      <span className="eyebrow">Publishing can wait</span>
      <p style={{ marginTop: 0 }}>
        This can still be your experience. Nothing was stored and your draft is safe — after the
        cooling period you can decide again, with the same words if you still mean them.
      </p>
      <div className="card-actions compose-actions">
        <button className="btn btn--primary" disabled={!ready} onClick={onRecheck}>
          {ready ? "Run the check again" : `Check again in ${formatRemaining(remaining)}`}
        </button>
        <button className="btn btn--ghost" disabled={saveBusy} onClick={onKeepPrivate}>
          Keep private meanwhile
        </button>
      </div>
    </section>
  );
}
