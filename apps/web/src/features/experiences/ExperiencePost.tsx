// One voice in the stream (review v3 §9.8 post anatomy, adjusted per Gary
// 2026-09-01): context line → the student's own words at the largest visual
// weight → one quiet footer (provenance · day · reactions · overflow). Short
// bodies render larger (post__body--feature) — the words are always the
// figure. No avatars, no anonymous badges, no verification shields.
//
// v2: reactions and reports are signed by the viewer's school/year reactor
// key and sent to the identity-free Community process; the viewer's own
// reaction is remembered on this device (the feed carries no per-viewer state).

import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import type { EntityRefV2, PublicExperienceV2 } from "@honey/shared/community-v2";
import { ApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { Modal } from "../../components/Modal";
import { myPosts, myReactions, reactToPost, reportPost, PostControlsUnavailable } from "../../lib/community-v2/publish-client";
import { formatDayBucket } from "../../lib/format";
import { PROVENANCE_LINE, Stars } from "../../pages/experiences/shared";
import { useT } from "../../lib/i18n";
import { PenIcon } from "../../components/icons";

const REACTION_EXPLAINER =
  "Reactions show whether this matches the experience of students who have had the same class or place. They do not verify a post as fact.";

function entityHref(e: EntityRefV2): string | null {
  if (e.type === "lesson") return null; // lessons have no public page
  return `/experiences/${e.type}/${encodeURIComponent(e.id)}`;
}

/** "AL ECON U4 · 朱昂明" — named parts off the payload (names joined from the directory). */
function contextParts(exp: PublicExperienceV2): EntityRefV2[] {
  const parts: EntityRefV2[] = [];
  const seen = new Set<string>();
  const push = (e: EntityRefV2 | undefined | null) => {
    if (!e || !e.name || seen.has(`${e.type}:${e.id}`)) return;
    seen.add(`${e.type}:${e.id}`);
    parts.push(e);
  };
  push(exp.contexts.find((c) => c.type === "course"));
  push(exp.contexts.find((c) => c.type === "teacher"));
  if (exp.primary.type !== "lesson") push(exp.primary);
  push(exp.contexts.find((c) => c.type === "room"));
  return parts;
}

const CLAMP_CHARS = 700; // ~8–12 lines before "Read more" (§9.7.2)
const FEATURE_CHARS = 180; // at/below this, the words set larger

/**
 * Resonance (Gary 2026-09-03: 共鸣) — a centre and the rings it sets going,
 * not a thumb. The reaction says "this rings true for me", which is what the
 * count has always meant; a thumb reads as approval of a person.
 */
function ResonanceIcon() {
  return (
    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="2.1" />
      <path d="M8.3 8.3a5.2 5.2 0 0 0 0 7.4" />
      <path d="M15.7 8.3a5.2 5.2 0 0 1 0 7.4" />
      <path d="M5.4 5.4a9.3 9.3 0 0 0 0 13.2" />
      <path d="M18.6 5.4a9.3 9.3 0 0 1 0 13.2" />
    </svg>
  );
}

/**
 * Where "write your own" goes from a post: the same subject when it has a
 * public one; a lesson is the writer's own and never the reader's, so those
 * fall back to the course or teacher, and finally to the picker.
 */
function composeHref(exp: PublicExperienceV2): string {
  const own =
    (exp.primary.type !== "lesson" ? exp.primary : null) ??
    exp.contexts.find((c) => c.type === "course") ??
    exp.contexts.find((c) => c.type === "teacher");
  return own ? `/experiences/compose?entityKey=${encodeURIComponent(`${own.type}:${own.id}`)}` : "/experiences/compose";
}

export function ExperiencePost({ exp }: { exp: PublicExperienceV2 }) {
  const { me } = useAuth();
  const [myValue, setMyValue] = useState<1 | -1 | 0>(() => myReactions.get(exp.id));
  const [counts, setCounts] = useState(exp.reactions);
  const [busy, setBusy] = useState(false);
  const [pendingValue, setPendingValue] = useState<1 | -1 | 0>(0);
  const [note, setNote] = useState<string | null>(null);
  const [options, setOptions] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const t = useT();
  const moreBtnRef = useRef<HTMLButtonElement>(null);

  const parts = contextParts(exp);
  const mine = myPosts.has(exp.id);
  const provenance = PROVENANCE_LINE[exp.provenance] ?? PROVENANCE_LINE.verified_member;
  const body = exp.body ?? "";
  const clamped = !expanded && body.length > CLAMP_CHARS;
  const shown = clamped ? body.slice(0, CLAMP_CHARS).replace(/\s+\S*$/, "") + "…" : body;

  async function react(value: 1 | -1) {
    if (busy) {
      setNote("Saving your reaction…");
      return;
    }
    if (!me) return;
    const prev = myValue;
    const prevCounts = counts;
    const next: 1 | -1 | 0 = myValue === value ? 0 : value;
    setBusy(true);
    setPendingValue(value);
    setNote(null);
    setMyValue(next);
    try {
      const result = await reactToPost(me.honeyId, exp.id, next);
      setMyValue(result.value);
      myReactions.set(exp.id, result.value);
      setCounts(result.reactions);
    } catch (err) {
      setMyValue(prev);
      setCounts(prevCounts);
      if (err instanceof PostControlsUnavailable) {
        setNote(err.reason === "restore_needed" ? "Restore your post controls in Settings to react." : "This browser cannot react (no post controls).");
      } else if (err instanceof ApiError && err.code === "reactions_disabled") {
        setNote("Reactions are paused right now.");
      } else if (err instanceof ApiError && err.code === "entity_frozen") {
        setNote("Reactions are paused for this entry.");
      } else {
        setNote("Could not save that reaction. Please try again.");
      }
    } finally {
      setBusy(false);
      setPendingValue(0);
      setNote((n) => (n === "Saving your reaction…" ? null : n));
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
      <div className="post__provenance">
        {/* Your own words, marked for you alone: the id is known on this
            device, never on the server (Gary 2026-09-03). */}
        {mine && <span className="post__mine">{t("Yours")} · </span>}
        {provenance}
        {exp.publishedDay !== null && <> · {formatDayBucket(exp.publishedDay)}</>}
      </div>
      {exp.rating !== null && <Stars value={exp.rating} />}
      <p className={body.length <= FEATURE_CHARS ? "post__body post__body--feature" : "post__body"}>{shown}</p>
      {clamped && (
        <button type="button" className="post__more" onClick={() => setExpanded(true)}>
          {t("Read more")}
        </button>
      )}

      <div className="post__actions">
        {/* Your own words: the count is there to read, but you cannot resonate
            with yourself and there is nothing to answer (Gary 2026-09-03). */}
        {mine ? (
          <span className="react-btn react-btn--static" title={REACTION_EXPLAINER}>
            <ResonanceIcon />
            {counts && <span className="react-btn__count">{counts.likes}</span>}
          </span>
        ) : (
          <>
            <button
              type="button"
              className={myValue === 1 ? "react-btn react-btn--on" : "react-btn"}
              title={REACTION_EXPLAINER}
              aria-pressed={myValue === 1}
              aria-label={t("This resonates with me")}
              aria-disabled={pendingValue === 1 || undefined}
              onClick={() => void react(1)}
            >
              <ResonanceIcon />
              {counts && <span className="react-btn__count">{counts.likes}</span>}
            </button>
            {/* Disagreement is not a down-vote (Gary 2026-09-03: down 去掉):
                a different experience is written down, not scored. */}
            <Link className="react-btn react-btn--write" to={composeHref(exp)}>
              <PenIcon size={16} />
              <span className="react-btn__label">{t("Write your own")}</span>
            </Link>
          </>
        )}
        <span className="post__spacer" />
        {/* Post options open as a sheet, not a floating menu (Gary 2026-09-03:
            report 选项打不开) — one surface, no outside-click listeners, and
            the same grammar as every other sheet in the app. */}
        <button
          type="button"
          className="react-btn react-btn--more"
          ref={moreBtnRef}
          aria-label={t("More options")}
          aria-haspopup="dialog"
          aria-expanded={options}
          onClick={() => setOptions(true)}
        >
          ···
        </button>
      </div>
      {note && <div className="caption post__note" role="status">{note}</div>}
      {options && me && (
        <PostOptionsSheet
          account={me.honeyId}
          experienceId={exp.id}
          onClose={() => {
            setOptions(false);
            moreBtnRef.current?.focus();
          }}
        />
      )}
    </article>
  );
}

// Category-only reporting (§3.9); disagreement is a reaction, not a report.
const REPORT_OPTIONS: { value: string; label: string }[] = [
  { value: "doxxing", label: "Private or identifying information" },
  { value: "slur", label: "Targeted abuse or a slur" },
  { value: "targets_student", label: "It is about a student" },
  { value: "serious_allegation", label: "A serious matter that should not be in the feed" },
  { value: "not_experience", label: "Rumor, spam, or not a real experience" },
  { value: "other_rule", label: "Another community-rule problem" },
];

/**
 * The post's options, as one sheet (Gary 2026-09-03: the floating menu could
 * not be opened on a phone). Step 1 is what you can do with this post; step 2
 * is the report's categories — no free text is ever collected, and the report
 * carries no account: it is signed by this device's reactor key, which
 * Community only knows as a tag.
 */
function PostOptionsSheet({ account, experienceId, onClose }: { account: string; experienceId: string; onClose: () => void }) {
  const [step, setStep] = useState<"options" | "report" | "done">("options");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const t = useT();

  async function send(category: string) {
    setBusy(true);
    setError(null);
    try {
      await reportPost(account, experienceId, category);
      setStep("done");
    } catch (err) {
      setError(
        err instanceof ApiError && err.code === "report_rate_limited"
          ? "You have reported a lot recently — please wait a while."
          : err instanceof ApiError && err.code === "reports_disabled"
            ? "Reporting is paused right now."
            : err instanceof PostControlsUnavailable
              ? "This browser cannot report."
              : "Could not send that report. Please try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  const title = step === "report" ? t("Report this experience") : step === "done" ? t("Report sent") : t("Post options");

  return (
    <Modal title={title} onClose={onClose} describedBy={step === "report" ? "report-dialog-body" : undefined}>
      {step === "options" && (
        <div className="report-options">
          <button className="btn btn--ghost btn--block" onClick={() => setStep("report")}>
            {t("Report this experience")}
          </button>
        </div>
      )}
      {step === "report" && (
        <>
          <p className="text-4" id="report-dialog-body">
            {t("Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected.")}
          </p>
          <div className="report-options">
            {REPORT_OPTIONS.map((o) => (
              <button key={o.value} className="btn btn--ghost btn--block" disabled={busy} onClick={() => void send(o.value)}>
                {t(o.label)}
              </button>
            ))}
          </div>
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
        </>
      )}
      {step === "done" && (
        <>
          <p>{t("Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote.")}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={onClose}>
              {t("Done")}
            </button>
          </div>
        </>
      )}
    </Modal>
  );
}
