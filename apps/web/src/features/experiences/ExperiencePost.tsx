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
import { myReactions, reactToPost, reportPost, PostControlsUnavailable } from "../../lib/community-v2/publish-client";
import { formatDayBucket } from "../../lib/format";
import { PROVENANCE_LINE, Stars } from "../../pages/experiences/shared";
import { useT } from "../../lib/i18n";

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

function ThumbUpIcon() {
  return (
    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M7 10v12" />
      <path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z" />
    </svg>
  );
}

function ThumbDownIcon() {
  return (
    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M17 14V2" />
      <path d="M9 18.12 10 14H4.17a2 2 0 0 1-1.92-2.56l2.33-8A2 2 0 0 1 6.5 2H20a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-2.76a2 2 0 0 0-1.79 1.11L12 22a3.13 3.13 0 0 1-3-3.88Z" />
    </svg>
  );
}

export function ExperiencePost({ exp }: { exp: PublicExperienceV2 }) {
  const { me } = useAuth();
  const [myValue, setMyValue] = useState<1 | -1 | 0>(() => myReactions.get(exp.id));
  const [counts, setCounts] = useState(exp.reactions);
  const [busy, setBusy] = useState(false);
  const [pendingValue, setPendingValue] = useState<1 | -1 | 0>(0);
  const [note, setNote] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const t = useT();
  const moreBtnRef = useRef<HTMLButtonElement>(null);
  const overflowRef = useRef<HTMLDivElement>(null);
  const firstItemRef = useRef<HTMLButtonElement>(null);
  const menuId = `post-menu-${exp.id}`;

  useEffect(() => {
    if (!menuOpen) return;
    firstItemRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setMenuOpen(false);
        moreBtnRef.current?.focus();
      }
    };
    const onPointer = (e: PointerEvent) => {
      const target = e.target as Element | null;
      if (overflowRef.current?.contains(target)) return;
      setMenuOpen(false);
      if (!target?.closest('button, a, input, textarea, select, [tabindex]:not([tabindex="-1"])')) {
        setTimeout(() => moreBtnRef.current?.focus(), 0);
      }
    };
    const onArrow = (e: KeyboardEvent) => {
      if (e.key !== "ArrowDown" && e.key !== "ArrowUp") return;
      const items = Array.from(overflowRef.current?.querySelectorAll<HTMLElement>('[role="menuitem"]') ?? []);
      if (items.length === 0) return;
      e.preventDefault();
      const i = items.indexOf(document.activeElement as HTMLElement);
      const next = e.key === "ArrowDown" ? (i + 1) % items.length : (i - 1 + items.length) % items.length;
      items[next]?.focus();
    };
    const onFocusOut = (e: FocusEvent) => {
      const next = e.relatedTarget as Node | null;
      if (next && !overflowRef.current?.contains(next)) setMenuOpen(false);
    };
    const group = overflowRef.current;
    document.addEventListener("keydown", onKey);
    document.addEventListener("keydown", onArrow);
    document.addEventListener("pointerdown", onPointer);
    group?.addEventListener("focusout", onFocusOut);
    return () => {
      document.removeEventListener("keydown", onKey);
      document.removeEventListener("keydown", onArrow);
      document.removeEventListener("pointerdown", onPointer);
      group?.removeEventListener("focusout", onFocusOut);
    };
  }, [menuOpen]);

  const parts = contextParts(exp);
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
        <button
          type="button"
          className={myValue === 1 ? "react-btn react-btn--on" : "react-btn"}
          title={REACTION_EXPLAINER}
          aria-pressed={myValue === 1}
          aria-label={t("Matches my experience")}
          aria-disabled={pendingValue === 1 || undefined}
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
          aria-label={t("Doesn’t match my experience")}
          aria-disabled={pendingValue === -1 || undefined}
          onClick={() => void react(-1)}
        >
          <ThumbDownIcon />
          {counts && <span className="react-btn__count">{counts.dislikes}</span>}
        </button>
        <span className="post__spacer" />
        <div className="post__overflow" ref={overflowRef}>
          <button
            type="button"
            className="react-btn react-btn--more"
            ref={moreBtnRef}
            aria-label={t("More options")}
            aria-haspopup="menu"
            aria-expanded={menuOpen}
            aria-controls={menuId}
            onClick={() => setMenuOpen((v) => !v)}
          >
            ···
          </button>
          {menuOpen && (
            <div className="post__menu" role="menu" id={menuId} aria-label="Post options">
              <button
                type="button"
                role="menuitem"
                ref={firstItemRef}
                onClick={() => {
                  moreBtnRef.current?.focus();
                  setMenuOpen(false);
                  setReporting(true);
                }}
              >
                {t("Report")}
              </button>
            </div>
          )}
        </div>
      </div>
      {note && <div className="caption post__note" role="status">{note}</div>}
      {reporting && me && (
        <PostReportDialog
          account={me.honeyId}
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
const REPORT_OPTIONS: { value: string; label: string }[] = [
  { value: "doxxing", label: "Private or identifying information" },
  { value: "slur", label: "Targeted abuse or a slur" },
  { value: "targets_student", label: "It is about a student" },
  { value: "serious_allegation", label: "A serious matter that should not be in the feed" },
  { value: "not_experience", label: "Rumor, spam, or not a real experience" },
  { value: "other_rule", label: "Another community-rule problem" },
];

function PostReportDialog({ account, experienceId, onClose }: { account: string; experienceId: string; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send(category: string) {
    setBusy(true);
    setError(null);
    try {
      await reportPost(account, experienceId, category);
      setDone(true);
    } catch (err) {
      setError(
        err instanceof ApiError && err.code === "report_rate_limited"
          ? "You have reported a lot recently — please wait a while."
          : err instanceof PostControlsUnavailable
            ? "Restore your post controls in Settings to report."
            : "Could not send that report. Please try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title="Report this experience" onClose={onClose} describedBy={done ? undefined : "report-dialog-body"}>
      {done ? (
        <>
          <p>Thanks. The post gets re-checked automatically under the current community rules — reports flag a rule problem; they are never a vote.</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={onClose}>
              Done
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="text-4" id="report-dialog-body">
            Disagreeing is not a report — use the reaction for that. Reports are for rule problems only, and no free text is collected.
          </p>
          <div className="report-options">
            {REPORT_OPTIONS.map((o) => (
              <button key={o.value} className="btn btn--ghost btn--block" disabled={busy} onClick={() => void send(o.value)}>
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
