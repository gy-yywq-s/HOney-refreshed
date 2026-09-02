// Scroll model: FRAMED_SCROLL (§16.14.2).
// /experiences/mine — the user's own words first (review v1.1 §10): private
// notes and shared posts as plain rows with quiet status labels. Shared
// posts are listed by cryptographic proof (the school/year posting key of
// every root this device holds) and removed with each post's own control
// key — no account lookup exists on either side.

import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { describeApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { ConfirmDialog } from "../../components/Modal";
import { ChevronRightIcon, PenIcon } from "../../components/icons";
import { formatCoarseDate, formatRemaining } from "../../lib/format";
import { privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote } from "../../lib/ownershipKeys";
import { communitySession, listOwnedPosts, revokePost, type OwnedPost } from "../../lib/community-v2/publish-client";
import { postControls } from "../../lib/community-v2/post-controls";
import { entityNames } from "../../lib/entityNames";
import { Skeleton } from "../../lib/motion";
import { apiCache } from "../../lib/useApi";
import { useRetryFocus } from "../../lib/useRetryFocus";
import { Stars, provenanceLabel } from "./shared";
import { t, useT } from "../../lib/i18n";

interface StatusMeta {
  label: string;
  tone: "ok" | "muted" | "danger";
  explain: string;
}

const STATUS_META: Record<string, StatusMeta> = {
  published: { label: "Shared", tone: "ok", explain: "" },
  blocked: {
    label: "Hidden",
    tone: "danger",
    explain: "This was hidden after a re-check against the current community rules. You can remove it if you want to write a new one about this.",
  },
};

type ControlsState = "loading" | "ready" | "none" | "restore_needed" | "unsupported";

export function ExperiencesMinePage() {
  const { me } = useAuth();
  const account = me?.honeyId ?? "";
  const [controls, setControls] = useState<ControlsState>("loading");
  const [shared, setShared] = useState<OwnedPost[] | null>(null);
  const [names, setNames] = useState<Map<string, string> | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notes, setNotes] = useState<PrivateNote[] | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(null);
  const [revoking, setRevoking] = useState<OwnedPost | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  useT();

  const loadShared = useCallback(async () => {
    if (!account) return;
    setError(null);
    try {
      const status = await postControls.status(account);
      if (status.kind === "unsupported" || status.kind === "restore_needed" || status.kind === "none") {
        setControls(status.kind);
        setShared([]);
        return;
      }
      setControls("ready");
      const [posts, n] = await Promise.all([listOwnedPosts(account), entityNames()]);
      setNames(n);
      setShared(posts);
    } catch (err) {
      setError(describeApiError(err));
      setShared([]);
    }
  }, [account]);

  const landing = useRetryFocus<HTMLDivElement>(shared === null);

  const loadNotes = useCallback(() => {
    void privateNotes.list().then(setNotes);
  }, []);
  useEffect(loadNotes, [loadNotes]);
  useEffect(() => {
    void loadShared();
  }, [loadShared]);

  const privateList = useMemo(() => [...(notes ?? [])].sort((a, b) => b.updatedAt - a.updatedAt), [notes]);

  if (!me) return null;

  function targetLabel(exp: OwnedPost): string {
    const name = (type: string, id: string) => names?.get(`${type}:${id}`) ?? null;
    if (exp.primaryEntity.type === "lesson") {
      const parts = ["Lesson"];
      const course = exp.contexts.find((c) => c.type === "course");
      const teacher = exp.contexts.find((c) => c.type === "teacher");
      if (course && name("course", course.id)) parts.push(name("course", course.id)!);
      if (teacher && name("teacher", teacher.id)) parts.push(name("teacher", teacher.id)!);
      return parts.join(" · ");
    }
    return name(exp.primaryEntity.type, exp.primaryEntity.id) ?? `${exp.primaryEntity.type}:${exp.primaryEntity.id}`;
  }

  async function revoke(post: OwnedPost) {
    setBusyId(post.id);
    setFeedback(null);
    try {
      const session = await communitySession();
      await revokePost(account, post, session.scope.schoolId);
      apiCache.invalidate("experiences");
      setFeedback({ tone: "success", text: "Removed. The post is gone — you can write a new one about this any time." });
      setRevoking(null);
      await loadShared();
    } catch {
      setFeedback({ tone: "danger", text: "Could not remove the post. Please try again." });
    } finally {
      setBusyId(null);
    }
  }

  async function deleteNote(id: string) {
    await privateNotes.remove(id);
    loadNotes();
  }

  const empty = (shared?.length ?? 0) === 0 && (notes?.length ?? 0) === 0 && controls !== "restore_needed";

  return (
    <div className="stack focus-landing" ref={landing.ref} tabIndex={-1} role="region" aria-label="Your notes & posts">
      <header className="page-head page-head--tools">
        <h1 className="page-title">{t("Your notes & posts")}</h1>
        {!empty && (
          <Link className="iconbtn iconbtn--primary" to="/experiences/compose" aria-label={t("Share an experience")} title={t("Share an experience")}>
            <PenIcon />
          </Link>
        )}
      </header>

      {controls === "ready" && (
        <Link className="row row--quiet" to="/settings/post-controls">
          <span className="row__main">
            <span className="row__title">{t("Post controls are on this device.")}</span>
          </span>
          <span className="row__act">
            {t("Manage")} <ChevronRightIcon size={16} />
          </span>
        </Link>
      )}
      {controls === "restore_needed" && (
        <Link className="row" to="/settings/post-controls">
          <span className="row__main">
            <span className="row__title">{t("Your shared posts are controlled from a backup this device has not restored yet.")}</span>
            <span className="row__sub">{t("Restore with a passkey, another device or your recovery words to see and remove them here.")}</span>
          </span>
          <ChevronRightIcon size={18} />
        </Link>
      )}
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      {error && (
        <div role="alert" className="banner banner--danger">
          <span>{error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); void loadShared(); }}>
            Try again
          </button>
        </div>
      )}

      {shared === null || notes === null ? (
        <Skeleton lines={4} />
      ) : empty ? (
        <div className="feed-empty">
          <p>
            <strong>{t("Nothing here yet.")}</strong>
          </p>
          <p className="muted">{t("Keep something private or share an Experience when you are ready.")}</p>
          <Link className="btn btn--primary" to="/experiences/compose">
            {t("Share an experience")}
          </Link>
        </div>
      ) : (
        <>
          {privateList.length > 0 && (
            <section aria-label="Private notes" className="mine-group">
              <h2 className="overline">{t("Private notes")}</h2>
              {privateList.map((note) => (
                <PrivateNoteRow key={note.id} note={note} onDelete={(id) => void deleteNote(id)} />
              ))}
            </section>
          )}
          {shared.length > 0 && (
            <section aria-label="Shared" className="mine-group">
              <h2 className="overline">{t("Shared")}</h2>
              {shared.map((exp) => (
                <SharedRow key={exp.id} exp={exp} label={targetLabel(exp)} busy={busyId === exp.id} onRevoke={() => setRevoking(exp)} />
              ))}
            </section>
          )}
        </>
      )}

      {revoking && (
        <ConfirmDialog
          title="Remove this post?"
          body="The post disappears for everyone and its text is deleted. You can write a new one about this later. This cannot be undone."
          confirmLabel="Remove post"
          danger
          busy={busyId === revoking.id}
          onClose={() => setRevoking(null)}
          onConfirm={() => void revoke(revoking)}
        />
      )}
    </div>
  );
}

function SharedRow({ exp, label, busy, onRevoke }: { exp: OwnedPost; label: string; busy: boolean; onRevoke: () => void }) {
  const meta = STATUS_META[exp.status] ?? { label: exp.status, tone: "muted" as const, explain: "" };
  return (
    <article className="mine-item">
      <div className="mine-item__meta">
        <span className="mine-item__context">{label}</span>
        <span className="caption">{formatCoarseDate(exp.createdAt)}</span>
      </div>
      {exp.rating !== null && <Stars value={exp.rating} />}
      {exp.body !== null ? <p className="mine-item__body">{exp.body}</p> : <p className="muted">(no text)</p>}
      {meta.explain && <p className="caption">{meta.explain}</p>}
      <div className="mine-item__foot">
        <span className={`mine-item__status mine-item__status--${meta.tone}`}>
          {meta.label} · {provenanceLabel(exp.provenance)}
        </span>
        <button type="button" className="btn btn--ghost btn--small" disabled={busy} onClick={onRevoke}>
          {t("Remove…")}
        </button>
      </div>
    </article>
  );
}

function PrivateNoteRow({ note, onDelete }: { note: PrivateNote; onDelete: (id: string) => void }) {
  const [confirming, setConfirming] = useState(false);
  const remaining = note.cooldown ? note.cooldown.until - Date.now() : 0;
  const cooling = !!note.cooldown && remaining > 0;
  const paused = !!note.cooldown && remaining <= 0;
  return (
    <article className="mine-item">
      <div className="mine-item__meta">
        <span className="mine-item__context">{note.target.label}</span>
        <span className="caption">{formatCoarseDate(note.updatedAt)}</span>
      </div>
      {note.rating !== null && <Stars value={note.rating} />}
      <p className="mine-item__body">{note.body}</p>
      <div className="mine-item__foot">
        {cooling ? (
          <span className="mine-item__status mine-item__status--cooling">
            {t("Cooling · you can share this in")} {formatRemaining(remaining)}
          </span>
        ) : paused ? (
          <span className="mine-item__status mine-item__status--ok">{t("Pause over · ready to share")}</span>
        ) : (
          <span className="mine-item__status mine-item__status--muted">{t("Private · only on this device")}</span>
        )}
        <span className="mine-item__actions">
          <Link className={paused ? "btn btn--primary btn--small" : "btn btn--ghost btn--small"} to={`/experiences/compose?noteId=${encodeURIComponent(note.id)}`}>
            {paused ? t("Share now") : cooling ? t("Edit") : t("Edit / share")}
          </Link>
          <button type="button" className="btn btn--ghost btn--small" onClick={() => setConfirming(true)}>
            {t("Delete")}
          </button>
        </span>
      </div>
      {confirming && (
        <ConfirmDialog
          title="Delete this private note?"
          body="The note exists only on this device; deleting it cannot be undone."
          confirmLabel="Delete note"
          danger
          onClose={() => setConfirming(false)}
          onConfirm={() => {
            setConfirming(false);
            onDelete(note.id);
          }}
        />
      )}
    </article>
  );
}
