// Shared building blocks for the Experiences surfaces: the post card
// (verbatim body, provenance, coarse date, reactions, report), star display /
// input, name resolution, and the "from your classes" feed hook.

import { useMemo, useState } from "react";
import { api, ApiError } from "../../api/client";
import type {
  DirectoryResponse,
  EntityRef,
  PublicExperience,
  ReportCategory,
} from "../../api/types";
import { Modal } from "../../components/Modal";
import { formatDayBucket } from "../../lib/format";
import { useApi } from "../../lib/useApi";

// ---------------------------------------------------------------------------
// Labels & paths
// ---------------------------------------------------------------------------

/** Spec §7.3: provenance is labeled honestly — never "verified use" for dishes. */
const PROVENANCE_LABELS: Record<string, string> = {
  verified_lesson: "Verified lesson experience",
  verified_retrospective: "Verified retrospective",
  verified_member: "Verified school member",
};

export function provenanceLabel(provenance: string): string {
  return PROVENANCE_LABELS[provenance] ?? "Verified school member";
}

export const REACTION_TOOLTIP =
  "These reflect whether people with the same verified exposure resonate; they do not rank posts";

/** Route for an entity page; the URL carries the id part of the entity_key. */
export function entityPath(entity: Pick<EntityRef, "entity_key" | "type">): string {
  const id = entity.entity_key.slice(entity.entity_key.indexOf(":") + 1);
  return `/experiences/${entity.type}/${encodeURIComponent(id)}`;
}

/** Friendly copy for every submit 422 the backend can return. */
/**
 * Gate-prefixed check reason codes → the ONE boundary sentence the user sees
 * (review v3 §10.4). Unknown/internal codes render nothing — detector details
 * are never a UI surface.
 */
const CHECK_REASON_COPY: Record<string, string> = {
  "standing:hearsay": "It describes something you heard rather than your own experience.",
  "expression:targeted_profanity":
    "Part of the wording targets a person rather than describing the experience.",
  "expression:targets_student":
    "It evaluates or identifies another student — students aren't public subjects here.",
  "expression:privacy_invasion":
    "It includes private details that could identify or expose someone.",
  "expression:lexical:identifying_information":
    "It includes contact or identifying information. Remove it — the experience can still be told.",
  "expression:injection_attempt":
    "Part of the text reads as instructions to the system rather than an experience.",
  "expression:uncertain":
    "HOney could not confidently understand part of this wording. Say it more directly.",
  "timing:high_arousal":
    "This can still be your experience. Publishing it can wait until you'd share it the same way tomorrow.",
  "composition:low_information":
    "A little context about what led you here can help another student — optional.",
  rating_not_allowed_for_entity: "Star ratings only exist for canteen dishes.",
};

export function describeCheckReasons(reasons: string[] | undefined): string[] {
  return (reasons ?? []).map((r) => CHECK_REASON_COPY[r]).filter((r): r is string => !!r);
}

export const SUBMIT_ERROR_COPY: Record<string, string> = {
  publications_disabled:
    "Publishing is paused for everyone right now. You can still save this privately and publish once posting reopens.",
  body_invalid: "The text is empty or longer than 5000 characters.",
  rating_invalid: "Stars are whole numbers from 1 to 5.",
  lesson_not_yours:
    "That lesson isn't in your imported history, so this account can't review it. Pick a lesson from your own History.",
  entity_unknown: "This entry isn't in the registry any more — it may have been removed.",
  entity_frozen: "New experiences for this entry are paused by the moderators right now.",
  standalone_closed: "Reviews for this entry are closed right now.",
  not_invited: "This entry is invite-only, and this account hasn't been invited to review it.",
  no_verified_exposure:
    "You can review teachers and rooms your imported timetable shows you've actually had — nothing in your history matches this entry.",
  rating_not_allowed:
    "Stars are for dishes only, never for people, lessons or rooms. Remove the rating to continue.",
  cooldown_ticket_invalid:
    "The cooling-off pass didn't match this draft (it changed since then). Run the check again — nothing was lost.",
  already_reviewed:
    "You've already shared an experience for this. You can revoke it in Your notes & posts if you want to write a new one.",
};

export function describeSubmitError(err: unknown): string {
  if (err instanceof ApiError && SUBMIT_ERROR_COPY[err.code]) return SUBMIT_ERROR_COPY[err.code]!;
  if (err instanceof ApiError && err.code === "network_error") {
    return "Could not reach the HOney server. Check your connection and try again.";
  }
  return "Something went wrong submitting this. Please try again.";
}

// ---------------------------------------------------------------------------
// Stars (dishes only)
// ---------------------------------------------------------------------------

export function Stars({ value }: { value: number }) {
  return (
    <span className="stars" role="img" aria-label={`${value} out of 5 stars`}>
      {"★★★★★".slice(0, value)}
      <span className="stars__empty">{"★★★★★".slice(value)}</span>
    </span>
  );
}

export function StarInput({
  value,
  onChange,
}: {
  value: number | null;
  onChange: (v: number | null) => void;
}) {
  return (
    <div className="star-input" role="radiogroup" aria-label="Dish rating (1 to 5 stars)">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          role="radio"
          aria-checked={value === n}
          aria-label={`${n} star${n > 1 ? "s" : ""}`}
          className={value !== null && n <= value ? "star-input__star star-input__star--on" : "star-input__star"}
          onClick={() => onChange(value === n ? null : n)}
        >
          ★
        </button>
      ))}
      {value !== null && (
        <button type="button" className="btn btn--ghost btn--small" onClick={() => onChange(null)}>
          Clear
        </button>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Name resolution (directory ids + entity registry → display names)
// ---------------------------------------------------------------------------

export interface NameMaps {
  teacher: Map<string, string>;
  course: Map<string, string>;
  room: Map<string, string>;
  /** entity_key → registry name (covers dishes and admin-imported entries). */
  entity: Map<string, string>;
}

export function buildNameMaps(
  directory: DirectoryResponse | null,
  entities: EntityRef[] | null,
): NameMaps {
  return {
    teacher: new Map(directory?.teachers.map((t) => [t.id, t.name]) ?? []),
    course: new Map(directory?.courses.map((c) => [c.id, c.name]) ?? []),
    room: new Map(directory?.rooms.map((r) => [r.id, r.name]) ?? []),
    entity: new Map(entities?.map((e) => [e.entity_key, e.name]) ?? []),
  };
}

/** One-line context ("Maths · Ms Lin · Room 204") from whatever ids resolve. */
export function contextLine(exp: PublicExperience, names: NameMaps): string {
  const parts: string[] = [];
  if (exp.ctx_course_id) {
    const n = names.course.get(exp.ctx_course_id);
    if (n) parts.push(n);
  }
  if (exp.ctx_teacher_id) {
    const n = names.teacher.get(exp.ctx_teacher_id) ?? names.entity.get(`teacher:${exp.ctx_teacher_id}`);
    if (n) parts.push(n);
  }
  if (exp.ctx_room_id) {
    const n = names.room.get(exp.ctx_room_id) ?? names.entity.get(`room:${exp.ctx_room_id}`);
    if (n) parts.push(n);
  }
  if (parts.length === 0 && !exp.entity_key.startsWith("lesson:")) {
    const n = names.entity.get(exp.entity_key);
    if (n) parts.push(n);
  }
  return parts.join(" · ");
}

/** Directory + entity registry in one hook (both are small, cached per page). */
export function useNames() {
  const directory = useApi(() => api.directory(), [], "directory");
  const entities = useApi(() => api.entities(), [], "entities");
  const names = useMemo(
    () => buildNameMaps(directory.data, entities.data?.entities ?? null),
    [directory.data, entities.data],
  );
  return { names, directory: directory.data, entities: entities.data?.entities ?? null };
}

// ---------------------------------------------------------------------------
// "From your classes" — a backend domain query (audit §4.2). The server knows
// the caller's verified exposure; the client no longer fetches the newest feed
// and filters it. Still chronological and unranked.
// ---------------------------------------------------------------------------

export function useFromYourClasses(limit = 100) {
  const feed = useApi(() => api.fromMyClasses({ limit }), [limit], `experiences:from-my-classes:${limit}`);
  return {
    experiences: feed.data?.experiences ?? null,
    loading: feed.loading,
    error: feed.error,
  };
}

// ---------------------------------------------------------------------------
// The post card
// ---------------------------------------------------------------------------

const REPORT_CATEGORIES: { value: ReportCategory; label: string }[] = [
  { value: "serious_allegation", label: "Serious allegation — needs investigation, not a feed" },
  { value: "doxxing", label: "Reveals private or identifying information" },
  { value: "slur", label: "Slur or dehumanizing language" },
  { value: "targets_student", label: "Targets a student" },
  { value: "not_experience", label: "Not an experience — rumor, secondhand story or spam" },
  { value: "other_rule", label: "Another community-rule problem" },
];

export function ExperienceCard({
  exp,
  names,
  showContext = true,
}: {
  exp: PublicExperience;
  names: NameMaps;
  showContext?: boolean;
}) {
  // The feed carries the viewer's own reaction (restored server-side from the
  // unlinkable dedup mark), so refresh/devices agree. Optimistic press, then
  // reconcile to the server's authoritative echo; roll back on failure.
  const [myValue, setMyValue] = useState<1 | -1 | 0>(exp.myReaction ?? 0);
  const [counts, setCounts] = useState(exp.reactions);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);
  const [reporting, setReporting] = useState(false);

  const ctx = showContext ? contextLine(exp, names) : "";

  async function react(value: 1 | -1) {
    if (busy) return;
    const prev = myValue;
    const prevCounts = counts;
    const next: 1 | -1 | 0 = myValue === value ? 0 : value;
    setBusy(true);
    setNote(null);
    setMyValue(next); // optimistic
    try {
      const result = await api.reactToExperience(exp.id, next);
      // Authoritative echo (review v3 §12.15C): render what the server states.
      setMyValue(result.value);
      setCounts(result.reactions);
    } catch (err) {
      setMyValue(prev); // rollback
      setCounts(prevCounts);
      if (err instanceof ApiError && err.code === "reactions_disabled") {
        setNote("Reactions are paused right now.");
      } else if (err instanceof ApiError && err.code === "not_eligible") {
        setNote("Reactions are open to people with the same verified exposure.");
      } else {
        setNote("Could not save that reaction. Please try again.");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <article className="card exp-card">
      <div className="exp-card__meta">
        <span className="exp-card__provenance">{provenanceLabel(exp.provenance)}</span>
        {exp.publishedDay !== null && (
          <span className="caption">{formatDayBucket(exp.publishedDay)}</span>
        )}
      </div>
      {ctx && <div className="caption exp-card__context">{ctx}</div>}
      {exp.rating !== null && <Stars value={exp.rating} />}
      {/* Raw-first: the body is rendered verbatim, whitespace preserved. */}
      <p className="exp-card__body">{exp.body}</p>
      <div className="exp-card__actions">
        <button
          type="button"
          className={myValue === 1 ? "react-btn react-btn--on" : "react-btn"}
          title={REACTION_TOOLTIP}
          aria-pressed={myValue === 1}
          disabled={busy}
          onClick={() => void react(1)}
        >
          Like{counts ? ` · ${counts.likes}` : ""}
        </button>
        <button
          type="button"
          className={myValue === -1 ? "react-btn react-btn--on" : "react-btn"}
          title={REACTION_TOOLTIP}
          aria-pressed={myValue === -1}
          disabled={busy}
          onClick={() => void react(-1)}
        >
          Dislike{counts ? ` · ${counts.dislikes}` : ""}
        </button>
        <span className="exp-card__spacer" />
        <button type="button" className="react-btn" onClick={() => setReporting(true)}>
          Report
        </button>
      </div>
      {note && <div className="caption exp-card__note">{note}</div>}
      {reporting && <ReportDialog experienceId={exp.id} onClose={() => setReporting(false)} />}
    </article>
  );
}

function ReportDialog({ experienceId, onClose }: { experienceId: string; onClose: () => void }) {
  const [category, setCategory] = useState<ReportCategory | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (!category || busy) return;
    setBusy(true);
    setError(null);
    try {
      await api.reportExperience(experienceId, category);
      setDone(true);
    } catch {
      setError("Could not send the report. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Report this post" onClose={onClose}>
      {done ? (
        <>
          <p className="muted">
            Thanks. The post has been automatically re-checked against the current community rules
            — no human queue, and no way to see who wrote it.
          </p>
          <div className="modal__actions modal__actions--row">
            <button className="btn btn--primary" onClick={onClose}>
              Done
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="muted">
            A report is for a rule violation — it is not a disagreement vote. If you simply
            disagree, that is what Dislike is for.
          </p>
          <div className="report-options">
            {REPORT_CATEGORIES.map((c) => (
              <label key={c.value} className="report-option">
                <input
                  type="radio"
                  name="report-category"
                  checked={category === c.value}
                  onChange={() => setCategory(c.value)}
                />
                <span>{c.label}</span>
              </label>
            ))}
          </div>
          <p className="caption">
            Reports are a category only — there is no free-text box. The post is automatically
            re-checked against the current rules; sensitive detail belongs with the school, not here.
          </p>
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
          <div className="modal__actions modal__actions--row">
            <button className="btn btn--ghost" onClick={onClose} disabled={busy}>
              Cancel
            </button>
            <button className="btn btn--primary" onClick={() => void submit()} disabled={!category || busy}>
              {busy ? "Sending…" : "Send report"}
            </button>
          </div>
        </>
      )}
    </Modal>
  );
}
