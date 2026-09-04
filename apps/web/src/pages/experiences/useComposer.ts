// Composer state machine (audit §3.3 real nudge, §3.4 draft preservation),
// on the v2 identity-free flow: post controls → blind eligibility → signed
// envelope → check → publish. `check` never persists the draft and never
// publishes; publication happens ONLY on an explicit user action. A `nudge`
// lane surfaces a preflight choice (add context / publish as is / keep
// private). Every non-publish outcome leaves the draft intact in the editor.

import { useCallback, useEffect, useRef, useState } from "react";
import { ApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { apiCache } from "../../lib/useApi";
import { composerDrafts } from "../../lib/composerDraft";
import { checkPost, preparePost, publishPost, PostControlsUnavailable, type PreparedPost } from "../../lib/community-v2/publish-client";
import { describeSubmitError } from "./shared";

export interface ComposerTarget {
  label: string;
  detail?: string;
  lessonId?: string;
  entityKey?: string;
  isDish: boolean;
}

export function targetKeyOf(target: ComposerTarget): string {
  return target.lessonId ? `lesson:${target.lessonId}` : (target.entityKey ?? "");
}

/** Inline banner shown above the editor for outcomes that keep the draft. */
export interface ComposerNotice {
  tone: "warn" | "danger";
  text: string;
  reasons?: string[];
  suggestKeepPrivate?: boolean;
  /** The device has no post controls and a backup exists elsewhere: link to restore. */
  restoreLink?: boolean;
}

export type ComposerStatus =
  | { kind: "editing" }
  | { kind: "checking" }
  | { kind: "nudge"; reasons: string[] }
  | { kind: "cooldown"; retryAt: number; reasons: string[] }
  | { kind: "published"; experienceId: string };

const EDIT_REQUIRED = "This wording can’t be shared here yet. Remove the insult or private detail, then say what happened or how it felt. Nothing was kept — your draft is still here.";
const OUT_OF_SCOPE = "This sounds like something that needs real support or action, not a public post. HOney won’t publish it or send it to the school. You can keep it for yourself instead.";
const BLOCKED = "This can't be published under the community rules. Nothing was stored — your draft is still here if you want to reshape it.";
const FAILED_CLOSED = "The safety check couldn't run just now, and nothing publishes unchecked. Your draft is safe — please try again in a moment.";
const RESTORE_NEEDED = "Your post controls are backed up but not on this device yet. Restore them in Settings › Post controls, then share.";
const UNSUPPORTED = "This browser cannot keep post controls, so it cannot publish. Use Safari, Chrome or the installed HOney app.";

export interface ComposerSeed {
  /** A private note that was cooling when it was kept: restore its ticket. */
  cooldown?: { until: number; ticket: string; body: string; rating: number | null } | undefined;
}

export function useComposer(target: ComposerTarget | null, seed?: ComposerSeed) {
  const { me } = useAuth();
  const account = me?.honeyId ?? "";
  const [body, setBody] = useState("");
  const [rating, setRating] = useState<number | null>(null);
  const [status, setStatus] = useState<ComposerStatus>({ kind: "editing" });
  const [notice, setNotice] = useState<ComposerNotice | null>(null);
  const [hydrated, setHydrated] = useState(false);

  // Held between a `nudge`/`cooldown` and the user's explicit follow-up action.
  const held = useRef<{ prepared: PreparedPost; pass: string } | null>(null);
  // The ticket is CONTENT-BOUND server-side (same body+rating only) — keep
  // the content it was issued for, so an edited draft re-checks fresh.
  const cooldownTicket = useRef<{ ticket: string; body: string; rating: number | null } | null>(null);

  const key = target ? targetKeyOf(target) : null;

  const seededTicket = seed?.cooldown?.ticket;
  useEffect(() => {
    const c = seed?.cooldown;
    if (!c) return;
    cooldownTicket.current = { ticket: c.ticket, body: c.body.trim(), rating: c.rating };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [seededTicket]);

  // Restore any saved draft for this target on mount (audit §3.4).
  useEffect(() => {
    if (!key) return;
    const saved = composerDrafts.get(key);
    if (saved) {
      setBody(saved.body);
      setRating(saved.rating);
    }
    setHydrated(true);
  }, [key]);

  // Autosave: keep the durable draft current with the editor.
  useEffect(() => {
    if (!key || !hydrated) return;
    if (body.trim().length === 0 && rating === null) return;
    composerDrafts.save({ targetKey: key, body, rating });
  }, [key, hydrated, body, rating]);

  const finishPublish = useCallback(
    async (prepared: PreparedPost, pass: string) => {
      const result = await publishPost(prepared, pass);
      apiCache.invalidate("experiences");
      if (key) composerDrafts.clear(key);
      setStatus({ kind: "published", experienceId: result.experienceId });
    },
    [key],
  );

  const failWith = useCallback((err: unknown) => {
    setStatus({ kind: "editing" });
    if (err instanceof PostControlsUnavailable) {
      setNotice(err.reason === "restore_needed" ? { tone: "warn", text: RESTORE_NEEDED, restoreLink: true } : { tone: "danger", text: UNSUPPORTED });
      return;
    }
    setNotice({ tone: "danger", text: describeSubmitError(err) });
  }, []);

  // post controls → eligibility → envelope → check → (publish | nudge | cooldown | keep-draft).
  const runCheck = useCallback(
    async (ticket?: string) => {
      if (!target || !key || !account) return;
      composerDrafts.save({ targetKey: key, body, rating });
      setStatus({ kind: "checking" });
      setNotice(null);
      held.current = null;
      try {
        const prepared = await preparePost(
          account,
          target.lessonId ? { lessonId: target.lessonId } : { entityKey: target.entityKey ?? "" },
          body,
          target.isDish && rating !== null ? rating : null,
        );
        const check = await checkPost(prepared, ticket);
        switch (check.lane) {
          case "publish":
            await finishPublish(prepared, check.pass!);
            break;
          case "nudge":
            held.current = { prepared, pass: check.pass! };
            setStatus({ kind: "nudge", reasons: check.reasons });
            break;
          case "cooldown":
            cooldownTicket.current = { ticket: check.cooldown!.ticket, body: body.trim(), rating };
            setStatus({ kind: "cooldown", retryAt: check.cooldown!.retryAt, reasons: check.reasons });
            break;
          case "edit_required":
            setStatus({ kind: "editing" });
            setNotice({ tone: "warn", text: EDIT_REQUIRED, reasons: check.reasons });
            break;
          case "out_of_scope":
            setStatus({ kind: "editing" });
            setNotice({ tone: "warn", text: OUT_OF_SCOPE, reasons: check.reasons, suggestKeepPrivate: true });
            break;
          case "blocked_serious":
            setStatus({ kind: "editing" });
            setNotice({ tone: "danger", text: BLOCKED });
            break;
          case "failed_closed":
            setStatus({ kind: "editing" });
            setNotice({ tone: "danger", text: FAILED_CLOSED });
            break;
        }
      } catch (err) {
        failWith(err);
      }
    },
    [target, key, account, body, rating, finishPublish, failWith],
  );

  // "Publish as is" from the nudge preflight: an explicit publish action.
  const publishAsIs = useCallback(async () => {
    const h = held.current;
    if (!h) return runCheck();
    setStatus({ kind: "checking" });
    try {
      await finishPublish(h.prepared, h.pass);
    } catch (err) {
      // A stale token/pass (10 min+ later) just re-runs the check.
      if (err instanceof ApiError && /token_|pass_/.test(err.code)) {
        held.current = null;
        return runCheck();
      }
      failWith(err);
    }
  }, [finishPublish, runCheck, failWith]);

  const recheckAfterCooldown = useCallback(() => {
    const h = cooldownTicket.current;
    const usable = h && h.body === body.trim() && h.rating === rating;
    return runCheck(usable ? h.ticket : undefined);
  }, [runCheck, body, rating]);

  /** The cooling ticket for the CURRENT text, or null when the text changed. */
  const heldCooldown = useCallback(() => {
    const h = cooldownTicket.current;
    return h && h.body === body.trim() && h.rating === rating ? h : null;
  }, [body, rating]);

  const backToEditing = useCallback(() => {
    held.current = null;
    setStatus({ kind: "editing" });
  }, []);

  return {
    body,
    setBody,
    rating,
    setRating,
    status,
    notice,
    publish: () => recheckAfterCooldown(),
    publishAsIs,
    recheckAfterCooldown,
    heldCooldown,
    backToEditing,
  };
}
