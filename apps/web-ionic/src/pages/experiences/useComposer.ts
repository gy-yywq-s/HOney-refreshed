// Composer state machine (audit §3.3 real nudge, §3.4 draft preservation).
//
// The publication flow is eligibility → check → publish. `check` never persists
// the draft and never publishes; publication happens ONLY on an explicit user
// action. A `nudge` lane surfaces a preflight choice (add context / publish as
// is / keep private) — it does not auto-publish. Every non-publish outcome
// leaves the draft intact in the editor.

import { useCallback, useEffect, useRef, useState } from "react";
import { api, ApiError } from "../../api/client";
import type { CheckExperienceInput } from "../../api/types";
import { apiCache } from "../../lib/useApi";
import { composerDrafts } from "../../lib/composerDraft";
import { ownershipKeys } from "../../lib/ownershipKeys";
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
}

export type ComposerStatus =
  | { kind: "editing" }
  | { kind: "checking" }
  | { kind: "nudge"; reasons: string[] }
  | { kind: "cooldown"; retryAt: number; reasons: string[] }
  | { kind: "published"; ownershipKey: string; experienceId: string };

const EDIT_REQUIRED =
  "This version needs a change before it can be shared. It was not published or stored on the HOney server; your draft remains saved in this browser.";
const OUT_OF_SCOPE = "This sounds more serious than something HOney Experiences is designed to publish. HOney will not post it or send it to the school. You can keep it privately instead.";
const BLOCKED =
  "This can't be published under the community rules. It was not published or stored on the HOney server; your draft remains saved in this browser if you want to reshape it.";
const FAILED_CLOSED = "The safety check couldn't run just now, and nothing publishes unchecked. Your draft is safe — please try again in a moment.";

export function useComposer(target: ComposerTarget | null) {
  const [body, setBody] = useState("");
  const [rating, setRating] = useState<number | null>(null);
  const [status, setStatus] = useState<ComposerStatus>({ kind: "editing" });
  const [notice, setNotice] = useState<ComposerNotice | null>(null);
  const [hydrated, setHydrated] = useState(false);

  // Held between a `nudge`/`cooldown` and the user's explicit follow-up action.
  const pass = useRef<{ eligibilityToken: string; pass: string } | null>(null);
  // The ticket is CONTENT-BOUND server-side (same body+rating only) — keep
  // the content it was issued for, so an edited draft re-checks fresh
  // instead of failing with an opaque cooldown_ticket_invalid (review L5).
  const cooldownTicket = useRef<{ ticket: string; body: string; rating: number | null } | null>(null);

  const key = target ? targetKeyOf(target) : null;

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

  const scope = useCallback((): { lessonId: string } | { entityKey: string } | null => {
    if (!target) return null;
    if (target.lessonId) return { lessonId: target.lessonId };
    if (target.entityKey) return { entityKey: target.entityKey };
    return null;
  }, [target]);

  const finishPublish = useCallback(
    async (eligibilityToken: string, contentPass: string) => {
      const result = await api.publishExperience({
        eligibilityToken,
        pass: contentPass,
        body: body.trim(),
        ...(target?.isDish && rating !== null ? { rating } : {}),
      });
      ownershipKeys.add({ key: result.ownershipKey, experienceId: result.experienceId });
      apiCache.invalidate("experiences");
      if (key) composerDrafts.clear(key);
      setStatus({ kind: "published", ownershipKey: result.ownershipKey, experienceId: result.experienceId });
    },
    [body, rating, target, key],
  );

  // eligibility → check → (publish | nudge | cooldown | keep-draft).
  const runCheck = useCallback(
    async (ticket?: string) => {
      const s = scope();
      if (!s || !key) return;
      // Persist the draft BEFORE any network call — nothing below can lose it.
      composerDrafts.save({ targetKey: key, body, rating });
      setStatus({ kind: "checking" });
      setNotice(null);
      pass.current = null;
      try {
        const elig = await api.experienceEligibility(s);
        const checkInput: CheckExperienceInput = {
          ...s,
          body: body.trim(),
          ...(target?.isDish && rating !== null ? { rating } : {}),
          ...(ticket ? { cooldownTicket: ticket } : {}),
        };
        const check = await api.checkExperience(checkInput);
        switch (check.lane) {
          case "publish":
            await finishPublish(elig.eligibilityToken, check.pass!);
            break;
          case "nudge":
            pass.current = { eligibilityToken: elig.eligibilityToken, pass: check.pass! };
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
        setStatus({ kind: "editing" });
        setNotice({ tone: "danger", text: describeSubmitError(err) });
      }
    },
    [scope, key, body, rating, target, finishPublish],
  );

  // "Publish as is" from the nudge preflight: an explicit publish action.
  const publishAsIs = useCallback(async () => {
    const held = pass.current;
    if (!held) return runCheck();
    setStatus({ kind: "checking" });
    try {
      await finishPublish(held.eligibilityToken, held.pass);
    } catch (err) {
      // A stale token/pass (rare — 10 min+ later) just re-runs the check.
      if (err instanceof ApiError && /eligibility_|pass_/.test(err.code)) {
        pass.current = null;
        return runCheck();
      }
      setStatus({ kind: "editing" });
      setNotice({ tone: "danger", text: describeSubmitError(err) });
    }
  }, [finishPublish, runCheck]);

  const recheckAfterCooldown = useCallback(() => {
    const held = cooldownTicket.current;
    // Edited since the cooldown? The ticket no longer matches the content —
    // run a fresh check (which may cool down again, correctly).
    const usable = held && held.body === body.trim() && held.rating === rating;
    return runCheck(usable ? held.ticket : undefined);
  }, [runCheck, body, rating]);

  // Leave the nudge preflight to add more context, keeping the draft.
  const backToEditing = useCallback(() => {
    pass.current = null;
    setStatus({ kind: "editing" });
  }, []);

  return {
    body,
    setBody,
    rating,
    setRating,
    status,
    notice,
    publish: () => runCheck(),
    publishAsIs,
    recheckAfterCooldown,
    backToEditing,
  };
}
