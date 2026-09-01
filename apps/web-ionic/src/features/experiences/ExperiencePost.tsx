// One voice in the stream (review v3 §9.8 post anatomy, adjusted per Gary
// 2026-09-01): context line → the student's own words at the largest visual
// weight → one quiet footer (provenance · day · reactions · overflow). The
// provenance moved BELOW the words so a one-line post still reads as words
// with context, not metadata with a caption. Short bodies render larger
// (post__body--feature) — the words are always the figure. No avatars, no
// anonymous badges, no verification shields.

import { useRef, useState } from "react";
import { IonPopover } from "@ionic/react";
import { Link } from "react-router-dom";
import { api, ApiError } from "../../api/client";
import type { EntitySummary, PublicExperience, ReportCategory } from "../../api/types";
import { Modal } from "../../components/Modal";
import { formatDayBucket } from "../../lib/format";
import { Stars } from "../../pages/experiences/shared";

/** Human provenance lines (§9.7.6): context a student can say out loud. */
const PROVENANCE_LINE: Record<string, string> = {
  verified_lesson: "from a class you’ve taken",
  verified_retrospective: "from someone who has taken this over time",
  verified_member: "from a student here",
};

const REACTION_EXPLAINER =
  "Reactions come from students whose school data shows the same class, teacher, course or place; for food, HOney confirms only school membership. They do not verify a post as fact.";

function entityHref(e: EntitySummary): string | null {
  if (e.type === "lesson") return null; // lessons have no public page
  const kind = e.type === "room" ? "room" : e.type;
  return `/experiences/${kind}/${encodeURIComponent(e.id)}`;
}

/** "Further Mathematics · Ms Lin" — named parts straight off the payload. */
function contextParts(exp: PublicExperience): EntitySummary[] {
  const parts: EntitySummary[] = [];
  const seen = new Set<string>();
  const push = (e: EntitySummary | undefined | null) => {
    if (!e || !e.name || seen.has(`${e.type}:${e.id}`)) return;
    seen.add(`${e.type}:${e.id}`);
    parts.push(e);
  };
  // Course reads first, then teacher, then the rest (§6.3 line grammar).
  push(exp.contexts?.find((c) => c.type === "course"));
  push(exp.contexts?.find((c) => c.type === "teacher"));
  if (exp.primary && exp.primary.type !== "lesson") push(exp.primary);
  push(exp.contexts?.find((c) => c.type === "room"));
  return parts;
}

const CLAMP_CHARS = 700; // ~8–12 lines before "Read more" (§9.7.2)
const FEATURE_CHARS = 180; // at/below this, the words set larger

function ThumbUpIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="16"
      height="16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M7 10v12" />
      <path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z" />
    </svg>
  );
}

function ThumbDownIcon() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="16"
      height="16"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M17 14V2" />
      <path d="M9 18.12 10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88Z" />
    </svg>
  );
}

export function ExperiencePost({ exp }: { exp: PublicExperience }) {
  const [myValue, setMyValue] = useState<1 | -1 | 0>(exp.myReaction ?? 0);
  const [counts, setCounts] = useState(exp.reactions);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [menuEvent, setMenuEvent] = useState<Event | undefined>(undefined);
  const [reporting, setReporting] = useState(false);
  const [expanded, setExpanded] = useState(false);
  // Focus home for the report dialog: its opener (the menu item) unmounts
  // when the menu closes, so Modal's restore would land on <body> (a11y
  // audit) — return focus to the persistent overflow trigger instead.
  const moreBtnRef = useRef<HTMLButtonElement>(null);

  const parts = contextParts(exp);
  const provenance = PROVENANCE_LINE[exp.provenance] ?? PROVENANCE_LINE.verified_member;
  const body = exp.body ?? "";
  const clamped = !expanded && body.length > CLAMP_CHARS;
  const shown = clamped ? body.slice(0, CLAMP_CHARS).replace(/\s+\S*$/, "") + "…" : body;

  async function react(value: 1 | -1) {
    if (busy) return;
    const prev = myValue;
    const prevCounts = counts;
    const next: 1 | -1 | 0 = myValue === value ? 0 : value;
    setBusy(true);
    setNote(null);
    setMyValue(next);
    try {
      const result = await api.reactToExperience(exp.id, next);
      setMyValue(result.value);
      setCounts(result.reactions);
    } catch (err) {
      setMyValue(prev);
      setCounts(prevCounts);
      if (err instanceof ApiError && err.code === "reactions_disabled") {
        setNote("Reactions are paused right now.");
      } else if (err instanceof ApiError && err.code === "not_eligible") {
        setNote("Reactions are open to students with the same verified exposure.");
      } else {
        setNote("Could not save that reaction. Please try again.");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <article className="post">
      {parts.length > 0 && (
        <div className="post__context">
          {parts.map((e, i) => {
            const href = entityHref(e);
            return (
              <span key={`${e.type}:${e.id}`}>
                {i > 0 && <span className="post__dot" aria-hidden="true"> · </span>}
                {href ? <Link to={href}>{e.name}</Link> : e.name}
              </span>
            );
          })}
        </div>
      )}
      {exp.rating !== null && <Stars value={exp.rating} />}
      {/* Raw-first: the words verbatim, whitespace kept, largest weight.
          Short posts set larger — one line must still read as the subject. */}
      <p className={body.length <= FEATURE_CHARS ? "post__body post__body--feature" : "post__body"}>
        {shown}
      </p>
      {clamped && (
        <button type="button" className="post__more" onClick={() => setExpanded(true)}>
          Read more
        </button>
      )}

      <div className="post__actions">
        <span className="post__provenance">
          {provenance}
          {exp.publishedDay !== null && <> · {formatDayBucket(exp.publishedDay)}</>}
        </span>
        <button
          type="button"
          className={myValue === 1 ? "react-btn react-btn--on" : "react-btn"}
          title={REACTION_EXPLAINER}
          aria-pressed={myValue === 1}
          aria-label="Matches my experience"
          disabled={busy}
          onClick={() => void react(1)}
        >
          <ThumbUpIcon />
          {counts && <span className="react-btn__count">{counts.likes}</span>}
        </button>
        <button
          type="button"
          className={myValue === -1 ? "react-btn react-btn--on" : "react-btn"}
          title={REACTION_EXPLAINER}
          aria-pressed={myValue === -1}
          aria-label="Doesn’t match my experience"
          disabled={busy}
          onClick={() => void react(-1)}
        >
          <ThumbDownIcon />
          {counts && <span className="react-btn__count">{counts.dislikes}</span>}
        </button>
        <div className="post__overflow">
          <button
            type="button"
            className="react-btn react-btn--more"
            ref={moreBtnRef}
            aria-label="More options"
            aria-expanded={menuOpen}
            onClick={(event) => {
              setMenuEvent(event.nativeEvent);
              setMenuOpen(true);
            }}
          >
            ···
          </button>
          <IonPopover
            className="post-popover"
            isOpen={menuOpen}
            event={menuEvent}
            onDidDismiss={() => {
              setMenuOpen(false);
              setMenuEvent(undefined);
            }}
          >
              <div className="post__menu post__menu--ionic" role="menu">
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    setMenuOpen(false);
                    setReporting(true);
                  }}
                >
                  Report
                </button>
              </div>
          </IonPopover>
        </div>
      </div>
      {note && <div className="caption post__note">{note}</div>}
      {reporting && (
        <PostReportDialog
          experienceId={exp.id}
          onClose={() => {
            setReporting(false);
            moreBtnRef.current?.focus();
          }}
        />
      )}
    </article>
  );
}

// Category-only reporting (§3.9); disagreement is a reaction, not a report.
const REPORT_OPTIONS: { value: ReportCategory; label: string }[] = [
  { value: "doxxing", label: "Private or identifying information" },
  { value: "slur", label: "Targeted abuse or a slur" },
  { value: "targets_student", label: "It is about a student" },
  { value: "serious_allegation", label: "A serious matter that should not be in the feed" },
  { value: "not_experience", label: "Rumor, spam, or not a real experience" },
  { value: "other_rule", label: "Another community-rule problem" },
];

function PostReportDialog({ experienceId, onClose }: { experienceId: string; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send(category: ReportCategory) {
    setBusy(true);
    setError(null);
    try {
      await api.reportExperience(experienceId, category);
      setDone(true);
    } catch (err) {
      setError(
        err instanceof ApiError && err.code === "report_rate_limited"
          ? "You have reported a lot recently — please wait a while."
          : "Could not send that report. Please try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Report this experience" onClose={onClose}>
      {done ? (
        <>
          <p>
            Thanks. The post gets re-checked automatically under the current community rules —
            reports flag a rule problem; they are never a vote.
          </p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={onClose}>
              Done
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="text-4">
            Disagreeing is not a report — use the reaction for that. Reports are for rule problems
            only, and no free text is collected.
          </p>
          <div className="report-options">
            {REPORT_OPTIONS.map((o) => (
              <button
                key={o.value}
                className="btn btn--ghost btn--block"
                disabled={busy}
                onClick={() => void send(o.value)}
              >
                {o.label}
              </button>
            ))}
          </div>
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
        </>
      )}
    </Modal>
  );
}
