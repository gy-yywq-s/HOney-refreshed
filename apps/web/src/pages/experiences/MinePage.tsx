// Scroll model: FRAMED_SCROLL (§16.14.2).
// /experiences/mine — the user's own words first (review v1.1 §10): private
// notes and shared posts as plain rows with quiet status labels; the
// device-held control is one low-priority row that links to Settings, and
// only escalates when something is actually wrong (orphaned keys).

import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { MyExperience } from "../../api/types";
import { ConfirmDialog } from "../../components/Modal";
import { ChevronRightIcon, PenIcon } from "../../components/icons";
import { formatCoarseDate, formatRemaining } from "../../lib/format";
import { ownershipKeys, privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote, StoredOwnershipKey } from "../../lib/ownershipKeys";
import { Skeleton } from "../../lib/motion";
import { apiCache, useApi } from "../../lib/useApi";
import { useRetryFocus } from "../../lib/useRetryFocus";
import { Stars, provenanceLabel, useNames } from "./shared";

interface StatusMeta {
  label: string;
  tone: "ok" | "muted" | "danger";
  explain: string;
}

// A "mine" row only ever exists for a post that was actually published — the
// check/publish split means rejected drafts are never stored. So the only
// statuses are published, later-hidden (blocked), and revoked.
const STATUS_META: Record<string, StatusMeta> = {
  published: { label: "Shared", tone: "ok", explain: "" },
  blocked: {
    label: "Hidden",
    tone: "danger",
    explain:
      "This was hidden after a re-check against the current community rules. You can remove it if you want to write a new one about this.",
  },
  revoked: {
    label: "Removed",
    tone: "muted",
    explain: "You removed this post — you can write a new one about this whenever you want.",
  },
};

export function ExperiencesMinePage() {
  const [keys, setKeys] = useState<StoredOwnershipKey[]>(() => ownershipKeys.list());
  const [notes, setNotes] = useState<PrivateNote[] | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(null);
  const [revoking, setRevoking] = useState<string | null>(null); // ownership key
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const { names, error: namesError, loading: namesLoading, reload: reloadNames } = useNames();

  const keyList = useMemo(() => keys.map((k) => k.key), [keys]);
  const mine = useApi(
    () =>
      keyList.length > 0
        ? api.myExperiences(keyList)
        : Promise.resolve({ experiences: [] as MyExperience[] }),
    [keyList.join(",")],
  );
  // Arm on every loading flag a retry on this page can toggle (r9 contract).
  const landing = useRetryFocus<HTMLDivElement>(mine.loading || namesLoading);

  const loadNotes = useCallback(() => {
    void privateNotes.list().then(setNotes);
  }, []);
  useEffect(loadNotes, [loadNotes]);

  const keyByExperienceId = useMemo(
    () => new Map(keys.map((k) => [k.experienceId, k.key])),
    [keys],
  );

  const shared = useMemo(
    () => [...(mine.data?.experiences ?? [])].sort((a, b) => b.created_at - a.created_at),
    [mine.data],
  );
  const privateList = useMemo(() => [...(notes ?? [])].sort((a, b) => b.updatedAt - a.updatedAt), [notes]);

  const orphanKeys = useMemo(() => {
    if (!mine.data) return [];
    const found = new Set(mine.data.experiences.map((e) => e.id));
    return keys.filter((k) => !found.has(k.experienceId));
  }, [mine.data, keys]);

  function targetLabel(exp: MyExperience): string {
    if (exp.entity_key.startsWith("lesson:")) {
      const parts = ["Lesson"];
      if (exp.ctx_course_id && names.course.get(exp.ctx_course_id))
        parts.push(names.course.get(exp.ctx_course_id)!);
      if (exp.ctx_teacher_id && names.teacher.get(exp.ctx_teacher_id))
        parts.push(names.teacher.get(exp.ctx_teacher_id)!);
      return parts.join(" · ");
    }
    return names.entity.get(exp.entity_key) ?? exp.entity_key;
  }

  async function revoke(ownershipKey: string) {
    setBusyKey(ownershipKey);
    setFeedback(null);
    try {
      await api.revokeExperience(ownershipKey);
      apiCache.invalidate("experiences");
      setFeedback({
        tone: "success",
        text: "Removed. The post is gone — you can write a new one about this any time.",
      });
      setRevoking(null);
      mine.reload();
    } catch {
      setFeedback({ tone: "danger", text: "Could not remove the post. Please try again." });
    } finally {
      setBusyKey(null);
    }
  }

  async function deleteNote(id: string) {
    await privateNotes.remove(id);
    loadNotes();
  }

  function forgetOrphans() {
    for (const k of orphanKeys) ownershipKeys.remove(k.key);
    setKeys(ownershipKeys.list());
  }

  const empty = keys.length === 0 && (notes?.length ?? 0) === 0;

  return (
    <div className="stack focus-landing" ref={landing.ref} tabIndex={-1} role="region" aria-label="Your notes & posts">
      <header className="page-head page-head--tools">
        <h1 className="page-title">Your notes &amp; posts</h1>
        {!empty && (
          <Link className="iconbtn iconbtn--primary" to="/experiences/compose" aria-label="Share an experience" title="Share an experience">
            <PenIcon />
          </Link>
        )}
      </header>

      {keys.length > 0 && (
        <Link className="row row--quiet" to="/settings/privacy#keys">
          <span className="row__main">
            <span className="row__title">Post controls are stored on this device.</span>
          </span>
          <span className="row__act">
            Manage <ChevronRightIcon size={16} />
          </span>
        </Link>
      )}
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      {namesError && (
        <div role="alert" className="banner banner--danger">
          <span>{namesError}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); reloadNames(); }}>
            Try again
          </button>
        </div>
      )}

      {empty ? (
        <div className="feed-empty">
          <p>
            <strong>Nothing here yet.</strong>
          </p>
          <p className="muted">Keep something private or share an Experience when you are ready.</p>
          <Link className="btn btn--primary" to="/experiences/compose">
            Share an experience
          </Link>
        </div>
      ) : mine.loading || notes === null ? (
        <Skeleton lines={4} />
      ) : mine.error ? (
        <div role="alert" className="banner banner--danger">
          <span>{mine.error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); mine.reload(); }}>
            Try again
          </button>
        </div>
      ) : (
        <>
          {privateList.length > 0 && (
            <section aria-label="Private notes" className="mine-group">
              <h2 className="overline">Private notes</h2>
              {privateList.map((note) => (
                <PrivateNoteRow key={note.id} note={note} onDelete={(id) => void deleteNote(id)} />
              ))}
            </section>
          )}
          {shared.length > 0 && (
            <section aria-label="Shared" className="mine-group">
              <h2 className="overline">Shared</h2>
              {shared.map((exp) => (
                <SharedRow
                  key={exp.id}
                  exp={exp}
                  label={targetLabel(exp)}
                  ownershipKey={keyByExperienceId.get(exp.id) ?? ""}
                  busy={busyKey === keyByExperienceId.get(exp.id)}
                  onRevoke={(k) => setRevoking(k)}
                />
              ))}
            </section>
          )}
          {orphanKeys.length > 0 && (
            <div className="banner banner--warning orphan-keys" role="status">
              <span>
                {orphanKeys.length === 1
                  ? "1 stored post control no longer matches a post on the server."
                  : `${orphanKeys.length} stored post controls no longer match a post on the server.`}
              </span>
              <button type="button" className="btn btn--ghost btn--small" onClick={forgetOrphans}>
                Forget {orphanKeys.length > 1 ? "them" : "it"}
              </button>
            </div>
          )}
        </>
      )}

      {revoking && (
        <ConfirmDialog
          title="Remove this post?"
          body="The post disappears for everyone and its text is deleted. You can write a new one about this later. This cannot be undone."
          confirmLabel="Remove post"
          danger
          busy={busyKey === revoking}
          onClose={() => setRevoking(null)}
          onConfirm={() => void revoke(revoking)}
        />
      )}
    </div>
  );
}

function SharedRow({
  exp,
  label,
  ownershipKey,
  busy,
  onRevoke,
}: {
  exp: MyExperience;
  label: string;
  ownershipKey: string;
  busy: boolean;
  onRevoke: (key: string) => void;
}) {
  const meta = STATUS_META[exp.status] ?? { label: exp.status, tone: "muted" as const, explain: "" };
  const canRevoke = exp.status !== "revoked";

  return (
    <article className="mine-item">
      <div className="mine-item__meta">
        <span className="mine-item__context">{label}</span>
        <span className="caption">{formatCoarseDate(exp.created_at)}</span>
      </div>
      {exp.rating !== null && <Stars value={exp.rating} />}
      {exp.body !== null ? (
        <p className="mine-item__body">{exp.body}</p>
      ) : (
        <p className="muted">
          {exp.status === "revoked" ? "(text deleted when you removed this post)" : "(no text)"}
        </p>
      )}
      {meta.explain && <p className="caption">{meta.explain}</p>}
      {exp.status_detail && <p className="caption">{exp.status_detail}</p>}
      <div className="mine-item__foot">
        <span className={`mine-item__status mine-item__status--${meta.tone}`}>
          {meta.label} · {provenanceLabel(exp.provenance)}
        </span>
        {ownershipKey && canRevoke && (
          <button
            type="button"
            className="btn btn--ghost btn--small"
            disabled={busy}
            onClick={() => onRevoke(ownershipKey)}
          >
            Remove…
          </button>
        )}
      </div>
    </article>
  );
}

function PrivateNoteRow({
  note,
  onDelete,
}: {
  note: PrivateNote;
  onDelete: (id: string) => void;
}) {
  const [confirming, setConfirming] = useState(false);
  // A note the check put into a pause is not an ordinary private note: it
  // says when it can be shared again (Gary 2026-09-02).
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
            Cooling · can be shared in {formatRemaining(remaining)}
          </span>
        ) : paused ? (
          <span className="mine-item__status mine-item__status--ok">Pause over · ready to share again</span>
        ) : (
          <span className="mine-item__status mine-item__status--muted">Private · only on this device</span>
        )}
        <span className="mine-item__actions">
          <Link
            className="btn btn--ghost btn--small"
            to={`/experiences/compose?noteId=${encodeURIComponent(note.id)}`}
          >
            Edit / share
          </Link>
          <button type="button" className="btn btn--ghost btn--small" onClick={() => setConfirming(true)}>
            Delete
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
