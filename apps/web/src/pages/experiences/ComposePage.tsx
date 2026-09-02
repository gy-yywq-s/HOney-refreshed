// Scroll model: FRAMED_EDITOR (§16.14.7) — the editor region absorbs keyboard/height changes.
// /experiences/compose?lessonId= | ?entityKey= | ?noteId= — write an
// experience. Culture hints (spec §4, the Six Checks) appear as quiet
// placeholder/hint text, never as checkboxes. Publication is deliberate:
// the draft is preserved locally (audit §3.4), moderation runs synchronously
// as a preflight, and a `nudge` asks the user to choose before anything is
// published (audit §3.3) — nothing is ever auto-published.

import { useEffect, useMemo, useRef, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, Lesson } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { useRetryFocus } from "../../lib/useRetryFocus";
import { Skeleton } from "../../lib/motion";
import { formatShortDate, formatTime, formatRemaining, formatRelativeDay } from "../../lib/format";
import { entityTitle, roomLabel } from "../../lib/displayNames";
import { ChevronRightIcon } from "../../components/icons";
import { privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote } from "../../lib/ownershipKeys";
import { StarInput, describeCheckReasons, useNames } from "./shared";
import { useComposer } from "./useComposer";
import type { ComposerSeed } from "./useComposer";
import type { ComposerTarget } from "./useComposer";

// ONE stable prompt (review v3 §10.4): the composer is a quiet place to put
// an experience into words, not a rotating morality display. Boundaries
// appear only when a specific gate asks for something.
const COMPOSE_PROMPT = "What was it like for you?";
const COMPOSE_HELPER = "A moment, a pattern, or just a feeling. Specific context can help, but it is not required.";

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
    effectiveEntityKey ? "entities" : undefined,
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
        // Never flash the raw key while the registry loads (r2 visual); an
        // unknown key after load is handled below (no editor).
        label: entity ? entityTitle(entity.type, entity.name) : "Loading…",
        detail:
          type === "room" ? "Place" : type === "dish" ? "Food" : type === "course" ? "Course" : "Teacher",
        entityKey: effectiveEntityKey,
        isDish: (entity?.type ?? type) === "dish",
      };
    }
    return null;
  }, [effectiveLessonId, effectiveEntityKey, history.data, entities.data]);

  // Chooser (review §9.2): the target is picked before the editor — the
  // student's last few lessons are the likeliest, so they are one tap away.
  const recentLessons = useApi(
    () => (target ? Promise.resolve(null) : api.history({ limit: 6, order: "desc" })),
    [target === null],
    target ? undefined : "history:recent",
  );
  const seed = useMemo<ComposerSeed | undefined>(
    () =>
      note?.cooldown
        ? { cooldown: { ...note.cooldown, body: note.body, rating: note.rating } }
        : undefined,
    [note],
  );
  const composer = useComposer(target, seed);
  const { names } = useNames(!!effectiveEntityKey);
  // Arm on every flag a retry on this screen reloads (r9 contract).
  const landing = useRetryFocus<HTMLElement>(entities.loading || history.loading || recentLessons.loading);
  const { body, setBody, rating, setRating, status, notice } = composer;

  // Republishing a private note: seed the composer from the note's text.
  useEffect(() => {
    if (!note) return;
    setBody(note.body);
    setRating(note.rating);
    // Intentionally seed once when the note loads.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [note]);

  async function savePrivately(opts: { quiet?: boolean } = {}) {
    if (saveBusy) return;
    setSaveBusy(true);
    setSaveError(null);
    try {
      // The cooling state travels with the note: the ticket for THIS text,
      // or nothing once the text changed.
      const held = composer.heldCooldown();
      const cooldown =
        status.kind === "cooldown" && held ? { until: status.retryAt, ticket: held.ticket } : null;
      const savedNote = await privateNotes.save({
        ...(note ? { id: note.id } : {}),
        body,
        rating: target?.isDish ? rating : null,
        cooldown,
        target: {
          label: target ? [target.label, target.detail].filter(Boolean).join(" · ") : "No target",
          ...(target?.lessonId ? { lessonId: target.lessonId } : {}),
          ...(target?.entityKey ? { entityKey: target.entityKey } : {}),
          ...(target?.isDish ? { entityType: "dish" } : {}),
        },
      });
      if (opts.quiet) setNote(savedNote);
      else setSaved(true);
    } catch {
      setSaveError("Could not save the note on this device.");
    } finally {
      setSaveBusy(false);
    }
  }

  // A cooling-off outcome keeps the words private on this device at once
  // (review §9.6): the note carries the remaining time and the ticket, so
  // Your notes & posts shows "can be shared in …" and the re-check reuses it.
  const keptForTicket = useRef<string | null>(null);
  useEffect(() => {
    if (status.kind !== "cooldown") return;
    const held = composer.heldCooldown();
    if (!held || keptForTicket.current === held.ticket) return;
    keptForTicket.current = held.ticket;
    void savePrivately({ quiet: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status.kind]);

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
            This browser keeps a one-time ownership key so you can manage or remove the post later.
            Keep it: what you wrote may still make you recognisable to people who know the
            situation.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/mine">
              Your notes &amp; posts
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
          </div>
        </section>
      </div>
    );
  }

  const busy = status.kind === "checking";
  // A kept note still in its pause: the same words cannot be shared before
  // the time is up (the button says when); edited words check afresh.
  const pauseUntil = note?.cooldown && composer.heldCooldown() ? note.cooldown.until : 0;
  const pausing = pauseUntil > Date.now();
  const canAct = body.trim().length > 0 && !busy && !pausing;
  // A key the registry no longer lists (deduped room, placeholder, typo URL):
  // say so, like the entity page does — never an editor the server refuses.
  const unlisted =
    !!effectiveEntityKey &&
    !!entities.data &&
    !entities.data.entities.some((e) => e.entity_key === effectiveEntityKey);
  // Registry still loading for an entity target: no editor yet (r4) — the
  // unlisted decision cannot be made before the data is here.
  if (effectiveEntityKey && !entities.data && !entities.error) {
    return (
      <div className="stack">
        <h1 className="page-title">Share an experience</h1>
        <Skeleton lines={4} />
      </div>
    );
  }
  // Lesson lookup (?lessonId=): a skeleton while History loads, a banner
  // with a retry when it fails — never an editor over an unknown lesson (r9).
  if (effectiveLessonId && !history.data && !history.error) {
    return (
      <div className="stack">
        <h1 className="page-title">Share an experience</h1>
        <Skeleton lines={4} />
      </div>
    );
  }
  if (effectiveLessonId && !history.data && history.error) {
    return (
      <div className="stack">
        <h1 className="page-title">Share an experience</h1>
        <section className="focus-landing" ref={landing.ref} tabIndex={-1} role="region" aria-label="Could not load">
          <div role="alert" className="banner banner--danger">
            <span>{history.error}</span>
            <button
              className="btn btn--ghost btn--small"
              onClick={() => {
                landing.arm();
                history.reload();
              }}
            >
              Try again
            </button>
          </div>
        </section>
      </div>
    );
  }
  // Registry failed: say so, offer a retry, never an editor (r5).
  if (effectiveEntityKey && !entities.data && entities.error) {
    return (
      <div className="stack">
        <h1 className="page-title">Share an experience</h1>
        <section
          className="focus-landing"
          ref={landing.ref}
          tabIndex={-1}
          role="region"
          aria-label="Could not load"
        >
          <div role="alert" className="banner banner--danger">
            <span>{entities.error}</span>
            <button
              className="btn btn--ghost btn--small"
              onClick={() => {
                landing.arm();
                entities.reload();
              }}
            >
              Try again
            </button>
          </div>
        </section>
      </div>
    );
  }
  if (unlisted) {
    // Same distinction as the entity page: a name the directory still knows
    // is a delisted duplicate (point at the survivor); an unknown id never
    // existed.
    const [kindRaw, entityId = ""] = effectiveEntityKey!.split(":");
    const kind = kindRaw ?? "";
    const knownName =
      (kind === "teacher" && names.teacher.get(entityId)) ||
      (kind === "room" && names.room.get(entityId)) ||
      (kind === "course" && names.course.get(entityId)) ||
      null;
    const survivor = knownName
      ? entities.data?.entities.find((e) => e.type === kind && e.name === knownName)
      : undefined;
    return (
      <div className="stack">
        <h1 className="page-title">Share an experience</h1>
        <section className="card">
          <p className="text-3">
            {knownName
              ? "This entry is no longer listed, so nothing can be shared about it."
              : "Nothing is listed at this address, so nothing can be shared about it."}
          </p>
          <div className="card-actions">
            {survivor ? (
              <Link
                className="btn btn--primary"
                to={`/experiences/compose?entityKey=${encodeURIComponent(survivor.entity_key)}`}
              >
                Open the current entry for {survivor.name}
              </Link>
            ) : (
              <Link className="btn btn--primary" to="/experiences/explore">
                Find someone or something
              </Link>
            )}
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="compose-screen">
      <h1 className="page-title">{target ? "Share an experience" : "What is this about?"}</h1>

      {target ? (
        <section className="compose-target" aria-label="What this is about">
          <div className="compose-target__row">
            <span className="eyebrow">About</span>
            {!noteId && (
              <Link className="compose-target__change" to="/experiences/compose">
                Change
              </Link>
            )}
          </div>
          <strong className="compose-target__label">{target.label}</strong>
          {target.detail && <span className="text-3">{target.detail}</span>}
        </section>
      ) : (
        /* The target picker (review v1.1 §7): plain rows, one tap to the
           editor; History and Explore are secondary rows, not hero buttons. */
        <section className="picker focus-landing" aria-label="What is this about?" ref={landing.ref} tabIndex={-1}>
          <p className="caption picker__hint">
            One of your own lessons, or a teacher, course, place or dish.
          </p>
          <h3 className="overline">Recent lessons</h3>
          {recentLessons.loading ? (
            <Skeleton lines={4} />
          ) : recentLessons.error ? (
            <div role="alert" className="banner banner--danger">
              <span>{recentLessons.error}</span>
              <button
                className="btn btn--ghost btn--small"
                onClick={() => {
                  landing.arm();
                  recentLessons.reload();
                }}
              >
                Try again
              </button>
            </div>
          ) : recentLessons.data && recentLessons.data.lessons.length > 0 ? (
            <ul className="entity-list">
              {recentLessons.data.lessons.slice(0, 6).map((l) => (
                <li key={l.id}>
                  <Link
                    className="entity-row"
                    to={`/experiences/compose?lessonId=${encodeURIComponent(l.id)}`}
                  >
                    <span className="entity-row__main">
                      <span className="entity-row__title">{l.subjectName}</span>
                      <span className="caption">
                        {[formatRelativeDay(l.startsAt), l.teacherName, roomLabel(l.roomName)]
                          .filter(Boolean)
                          .join(" · ")}
                      </span>
                    </span>
                    <ChevronRightIcon size={18} />
                  </Link>
                </li>
              ))}
            </ul>
          ) : (
            <p className="caption">No lessons in your history yet.</p>
          )}
          <ul className="entity-list">
            <li>
              <Link className="entity-row" to="/history?select=1">
                <span className="entity-row__main">
                  <span className="entity-row__title">See full History</span>
                </span>
                <ChevronRightIcon size={18} />
              </Link>
            </li>
          </ul>
          <h3 className="overline">Other school context</h3>
          <ul className="entity-list">
            <li>
              <Link className="entity-row" to="/experiences/explore">
                <span className="entity-row__main">
                  <span className="entity-row__title">Teachers, courses, places and food</span>
                </span>
                <ChevronRightIcon size={18} />
              </Link>
            </li>
          </ul>
        </section>
      )}

      {target && (
        <section className="compose-editor focus-landing" ref={landing.ref} tabIndex={-1} role="region" aria-label="Editor">
          <div className="field">
            <label className="field__label" htmlFor="compose-body">
              {COMPOSE_PROMPT}
            </label>
            <textarea
              id="compose-body"
              className="input compose-textarea"
              rows={4}
              maxLength={5000}
              placeholder="Your own experience, in your own words"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              disabled={status.kind === "nudge"}
            />
            <span className="text-4 compose-hint">{COMPOSE_HELPER}</span>
            {body.trim().length > 0 && (
              <span className="caption compose-draft" role="status">
                Draft saved on this device
              </span>
            )}
          </div>

          {target.isDish && (
            <div className="field">
              <span className="field__label">Rating (dishes only — optional)</span>
              <StarInput value={rating} onChange={setRating} />
            </div>
          )}

          {pausing && !notice && (
            <div className="banner banner--warning" role="status">
              <span>
                Cooling · you can share these words in {formatRemaining(pauseUntil - Date.now())}. Edit them
                to say it differently and check again now.
              </span>
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
                  <p className="text-4 compose-notice-alt">You can keep it as a private note instead.</p>
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
            <CooldownPanel retryAt={status.retryAt} onOk={() => navigate("/experiences/mine", { replace: true })} />
          ) : (
            <div className="card-actions compose-actions">
              <button
                className="btn btn--primary"
                disabled={!canAct}
                onClick={() => void composer.publish()}
              >
                {busy
                  ? "Checking…"
                  : pausing
                    ? `Share in ${formatRemaining(pauseUntil - Date.now())}`
                    : note?.cooldown
                      ? "Share now"
                      : "Continue to share"}
              </button>
              <button
                className="btn btn--ghost"
                disabled={saveBusy || body.trim().length === 0 || busy}
                onClick={() => void savePrivately()}
              >
                {saveBusy ? "Saving…" : "Keep private"}
              </button>
            </div>
          )}

          <p className="text-4" style={{ marginBottom: 0 }}>
            Public sharing runs a text check. Public Experiences are stored without an ordinary
            author field. <Link to="/settings/privacy">How anonymity works</Link>
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
        This can be shared as it is. Is there anything that would help someone understand what you
        mean?
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
          Add a little context
        </button>
        <button className="btn btn--ghost" disabled={busy || saveBusy} onClick={onKeepPrivate}>
          Keep private
        </button>
      </div>
    </section>
  );
}

function CooldownPanel({ retryAt, onOk }: { retryAt: number; onOk: () => void }) {
  const remaining = Math.max(0, retryAt - Date.now());
  return (
    <section className="card nudge" aria-label="Cooling off">
      <span className="eyebrow">Publishing can wait</span>
      <p style={{ marginTop: 0 }}>
        Your words are kept in your private notes on this device. You can share them in{" "}
        {formatRemaining(remaining)} — or edit them to say it differently and check again sooner.
      </p>
      <p className="text-3" style={{ marginTop: 0 }}>
        This is a pause, not a judgment about your experience.
      </p>
      <div className="card-actions compose-actions">
        <button className="btn btn--primary" onClick={onOk}>
          OK
        </button>
      </div>
    </section>
  );
}
