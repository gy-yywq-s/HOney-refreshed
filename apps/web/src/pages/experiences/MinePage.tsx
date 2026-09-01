// Scroll model: FRAMED_SCROLL (§16.14.2).
// /experiences/mine — the user's own contributions: server-side submissions
// (proved by device-held ownership keys) merged with local private notes.
// Private notes are visually distinct; they never left this browser.

import { useCallback, useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { MyExperience } from "../../api/types";
import { ConfirmDialog } from "../../components/Modal";
import { formatCoarseDate } from "../../lib/format";
import { ownershipKeys, privateNotes } from "../../lib/ownershipKeys";
import type { PrivateNote, StoredOwnershipKey } from "../../lib/ownershipKeys";
import { Skeleton } from "../../lib/motion";
import { apiCache, useApi } from "../../lib/useApi";
import { Stars, provenanceLabel, useNames } from "./shared";

interface StatusMeta {
  chip: string;
  tone: "ok" | "muted" | "danger";
  explain: string;
}

// A "mine" row only ever exists for a post that was actually published — the
// check/publish split means rejected drafts are never stored. So the only
// statuses are published, later-hidden (blocked), and revoked.
const STATUS_META: Record<string, StatusMeta> = {
  published: { chip: "Published", tone: "ok", explain: "" },
  blocked: {
    chip: "Hidden",
    tone: "danger",
    explain:
      "This was hidden after a re-check against the current community rules. You can revoke it to free your review slot for this target.",
  },
  revoked: {
    chip: "Revoked",
    tone: "muted",
    explain: "You removed this post; your review slot for this target is free again.",
  },
};

export function ExperiencesMinePage() {
  const [keys, setKeys] = useState<StoredOwnershipKey[]>(() => ownershipKeys.list());
  const [notes, setNotes] = useState<PrivateNote[] | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(null);
  const [revoking, setRevoking] = useState<string | null>(null); // ownership key
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const { names } = useNames();

  const keyList = useMemo(() => keys.map((k) => k.key), [keys]);
  const mine = useApi(
    () =>
      keyList.length > 0
        ? api.myExperiences(keyList)
        : Promise.resolve({ experiences: [] as MyExperience[] }),
    [keyList.join(",")],
  );

  const loadNotes = useCallback(() => {
    void privateNotes.list().then(setNotes);
  }, []);
  useEffect(loadNotes, [loadNotes]);

  const keyByExperienceId = useMemo(
    () => new Map(keys.map((k) => [k.experienceId, k.key])),
    [keys],
  );

  // Merge server rows and private notes into one reverse-chronological list.
  const items = useMemo(() => {
    const rows: { at: number; el: "exp" | "note"; exp?: MyExperience; note?: PrivateNote }[] = [];
    for (const exp of mine.data?.experiences ?? []) rows.push({ at: exp.created_at, el: "exp", exp });
    for (const note of notes ?? []) rows.push({ at: note.updatedAt, el: "note", note });
    return rows.sort((a, b) => b.at - a.at);
  }, [mine.data, notes]);

  const orphanKeys = useMemo(() => {
    if (!mine.data) return [];
    const found = new Set(mine.data.experiences.map((e) => e.id));
    return keys.filter((k) => !found.has(k.experienceId));
  }, [mine.data, keys]);

  function targetLabel(exp: MyExperience): string {
    if (exp.entity_key.startsWith("lesson:")) {
      const parts = ["Lesson experience"];
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
        text: "Revoked. The post is gone and your review slot is free again.",
      });
      setRevoking(null);
      mine.reload();
    } catch {
      setFeedback({ tone: "danger", text: "Could not revoke. Please try again." });
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
    <div className="stack">
      <header className="page-head">
        {/* "My submissions/contributions" is administrative language (review v3
            §10.5) — this page is the user's own notes & posts. */}
        <h1 className="page-title">Your notes &amp; posts</h1>
        <Link className="btn btn--primary" to="/experiences/compose">
          Share an experience
        </Link>
      </header>

      {keys.length > 0 && (
        <div role="status" className="banner banner--warning">
          Your ownership keys exist only in this browser. Clearing site data permanently removes
          your control over these posts.
        </div>
      )}
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}

      {empty ? (
        <section className="card">
          <h2 className="section-title">Nothing here yet</h2>
          <p className="muted">
            Published experiences are stored without an author ID. Each one hands this browser a
            one-time ownership key — that key is the only control over the post that exists, and it
            is how this page finds and revokes your posts. Private notes live here too, scrambled at
            rest, without ever leaving the device.
          </p>
          <div className="card-actions">
            <Link className="btn btn--primary" to="/experiences/compose">
              Share your first experience
            </Link>
          </div>
        </section>
      ) : mine.loading || notes === null ? (
        <Skeleton lines={3} />
      ) : mine.error ? (
        <div role="alert" className="banner banner--danger">{mine.error}</div>
      ) : (
        <div className="stack">
          {items.map((item) =>
            item.el === "exp" ? (
              <MineExperienceCard
                key={item.exp!.id}
                exp={item.exp!}
                label={targetLabel(item.exp!)}
                ownershipKey={keyByExperienceId.get(item.exp!.id) ?? ""}
                busy={busyKey === keyByExperienceId.get(item.exp!.id)}
                onRevoke={(k) => setRevoking(k)}
              />
            ) : (
              <PrivateNoteCard
                key={item.note!.id}
                note={item.note!}
                onDelete={(id) => void deleteNote(id)}
              />
            ),
          )}
          {orphanKeys.length > 0 && (
            <div className="caption orphan-keys">
              {orphanKeys.length} stored key{orphanKeys.length > 1 ? "s" : ""} no longer match a
              post on the server.{" "}
              <button type="button" className="btn btn--ghost btn--small" onClick={forgetOrphans}>
                Forget {orphanKeys.length > 1 ? "them" : "it"}
              </button>
            </div>
          )}
        </div>
      )}

      {revoking && (
        <ConfirmDialog
          title="Revoke this experience?"
          body="The post is removed for everyone and its text deleted. Your one-review slot for this target frees up again. This cannot be undone."
          confirmLabel="Revoke post"
          danger
          busy={busyKey === revoking}
          onClose={() => setRevoking(null)}
          onConfirm={() => void revoke(revoking)}
        />
      )}
    </div>
  );
}

function MineExperienceCard({
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
  const meta = STATUS_META[exp.status] ?? {
    chip: exp.status,
    tone: "muted" as const,
    explain: "",
  };
  const canRevoke = exp.status !== "revoked";

  return (
    <article className="card exp-card">
      <div className="exp-card__meta">
        <span className={`chip chip--${meta.tone}`}>{meta.chip}</span>
        <span className="exp-card__provenance">{provenanceLabel(exp.provenance)}</span>
        <span className="caption">{formatCoarseDate(exp.created_at)}</span>
      </div>
      <div className="caption exp-card__context">{label}</div>
      {exp.rating !== null && <Stars value={exp.rating} />}
      {exp.body !== null ? (
        <p className="exp-card__body">{exp.body}</p>
      ) : (
        <p className="muted">
          {exp.status === "revoked" ? "(text deleted when you revoked this post)" : "(no text)"}
        </p>
      )}
      {meta.explain && <p className="caption exp-card__note">{meta.explain}</p>}
      {exp.status_detail && <p className="caption exp-card__note">{exp.status_detail}</p>}
      {ownershipKey && canRevoke && (
        <div className="exp-card__actions">
          <button
            type="button"
            className="btn btn--ghost btn--small"
            disabled={busy}
            onClick={() => onRevoke(ownershipKey)}
          >
            Revoke…
          </button>
        </div>
      )}
    </article>
  );
}

function PrivateNoteCard({
  note,
  onDelete,
}: {
  note: PrivateNote;
  onDelete: (id: string) => void;
}) {
  const [confirming, setConfirming] = useState(false);
  return (
    <article className="card exp-card exp-card--private">
      <div className="exp-card__meta">
        <span className="chip chip--private">Private — only on this device</span>
        <span className="caption">{formatCoarseDate(note.updatedAt)}</span>
      </div>
      <div className="caption exp-card__context">{note.target.label}</div>
      {note.rating !== null && <Stars value={note.rating} />}
      <p className="exp-card__body">{note.body}</p>
      <div className="exp-card__actions">
        <Link
          className="btn btn--ghost btn--small"
          to={`/experiences/compose?noteId=${encodeURIComponent(note.id)}`}
        >
          Edit / publish…
        </Link>
        <button
          type="button"
          className="btn btn--ghost btn--small"
          onClick={() => setConfirming(true)}
        >
          Delete
        </button>
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
