// /experiences/compose?lessonId= | ?entityKey= | ?noteId= — write an
// experience. Culture hints (spec §4, the Six Checks) appear as quiet
// placeholder/hint text, never as checkboxes. Submission is async: the server
// answers immediately with a device-held ownership key, and moderation runs in
// the background.

import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { api } from "../../api/client";
import type { EntityRef, Lesson } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { formatShortDate, formatTime } from "../../lib/format";
import { ownershipKeys, privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote } from "../../lib/ownershipKeys";
import { StarInput, describeSubmitError } from "./shared";

// Six-Checks-derived contextual hints (spec §4: "contextually in composer
// prompts ... rather than a mandatory six-checkbox ritual").
const PLACEHOLDER_HINTS = [
  "Your own experience, as you experienced it",
  "What was it like for you? You don't have to turn it into advice",
  "A specific moment helps another student more than a verdict",
];
const FOOTER_HINTS = [
  "Was it like this every time, or that one lesson?",
  "Feelings can be stated as feelings — “I felt lost” is real testimony.",
  "Strong criticism is fine. Keep people human.",
  "If it reveals something that isn't yours to publish, leave it out.",
  "If it would need investigation or discipline, it belongs with the school, not a feed.",
  "More context, fewer verdicts.",
];

interface Target {
  label: string;
  detail?: string;
  lessonId?: string;
  entityKey?: string;
  isDish: boolean;
}

export function ExperiencesComposePage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const lessonId = searchParams.get("lessonId");
  const entityKeyParam = searchParams.get("entityKey");
  const noteId = searchParams.get("noteId");

  const [body, setBody] = useState("");
  const [rating, setRating] = useState<number | null>(null);
  const [note, setNote] = useState<PrivateNote | null>(null);
  const [busy, setBusy] = useState<"submit" | "save" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Stable per-mount hint pick — quiet variety without churn while typing.
  const hints = useMemo(
    () => ({
      placeholder: PLACEHOLDER_HINTS[Math.floor(Math.random() * PLACEHOLDER_HINTS.length)]!,
      footer: FOOTER_HINTS[Math.floor(Math.random() * FOOTER_HINTS.length)]!,
    }),
    [],
  );

  // Republishing a private note: prefill body/rating/target from the note.
  useEffect(() => {
    if (!noteId) return;
    void privateNotes.get(noteId).then((n) => {
      if (!n) return;
      setNote(n);
      setBody(n.body);
      setRating(n.rating);
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

  const target = useMemo<Target | null>(() => {
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

  async function submit() {
    if (!target || busy) return;
    setBusy("submit");
    setError(null);
    try {
      const result = await api.submitExperience({
        ...(target.lessonId ? { lessonId: target.lessonId } : {}),
        ...(target.entityKey ? { entityKey: target.entityKey } : {}),
        body: body.trim(),
        ...(target.isDish && rating !== null ? { rating } : {}),
      });
      // The ownership key is shown exactly once by the server — persist it
      // immediately; it is the only control anyone will ever have over this post.
      ownershipKeys.add({ key: result.ownershipKey, experienceId: result.experienceId });
      setSubmitted(true);
    } catch (err) {
      setError(describeSubmitError(err));
    } finally {
      setBusy(null);
    }
  }

  async function savePrivately() {
    if (busy) return;
    setBusy("save");
    setError(null);
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
      setError("Could not save the note on this device.");
    } finally {
      setBusy(null);
    }
  }

  if (submitted) {
    return (
      <div className="stack">
        <h1 className="page-title">Submitted</h1>
        <section className="card">
          <h2 className="section-title">Being checked — usually a few seconds</h2>
          <p className="muted">
            Every public word goes through the same automatic check before anyone sees it. There is
            no human queue and nothing links the post to you — your control over it is the key just
            saved to this browser.
          </p>
          <p className="muted">
            If the checker reads the wording as very heated, the post is instead saved privately
            for 24 hours — you can publish it after reconfirming, once the cooling-off window
            passes. You can watch the status in My contributions.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/mine">
              My contributions
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
        <h1 className="page-title">Saved privately</h1>
        <section className="card">
          <p className="muted">
            The note is encrypted and stays only on this device — it was never sent anywhere. You
            can edit, delete or publish it later from My contributions.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/mine">
              My contributions
            </Link>
            <Link className="btn btn--ghost" to="/experiences">
              Back to Experiences
            </Link>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="stack">
      <h1 className="page-title">Share an experience</h1>

      {target ? (
        <section className="card compose-target" aria-label="What this is about">
          <span className="overline">About</span>
          <strong>{target.label}</strong>
          {target.detail && <span className="caption">{target.detail}</span>}
        </section>
      ) : (
        <section className="card" aria-label="Pick a target">
          <p className="muted">
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
        <section className="card">
          <div className="field">
            <label className="field__label" htmlFor="compose-body">
              Your experience
            </label>
            <textarea
              id="compose-body"
              className="input compose-textarea"
              rows={7}
              maxLength={5000}
              placeholder={hints.placeholder}
              value={body}
              onChange={(e) => setBody(e.target.value)}
            />
            <span className="caption compose-hint">{hints.footer}</span>
          </div>

          {target.isDish && (
            <div className="field">
              <span className="field__label">Rating (dishes only — optional)</span>
              <StarInput value={rating} onChange={setRating} />
            </div>
          )}

          {error && <div className="banner banner--danger">{error}</div>}

          <div className="card-actions">
            <button
              className="btn btn--primary"
              disabled={busy !== null || body.trim().length === 0}
              onClick={() => void submit()}
            >
              {busy === "submit" ? "Submitting…" : "Publish anonymously"}
            </button>
            <button
              className="btn btn--ghost"
              disabled={busy !== null || body.trim().length === 0}
              onClick={() => void savePrivately()}
            >
              {busy === "save" ? "Saving…" : "Save privately instead"}
            </button>
            <button className="btn btn--ghost" disabled={busy !== null} onClick={() => navigate(-1)}>
              Cancel
            </button>
          </div>
          <p className="caption" style={{ marginBottom: 0 }}>
            Published posts carry no author. Your only control over this post will be a key stored
            in this browser. Private notes never leave this device.
          </p>
        </section>
      )}
    </div>
  );
}
