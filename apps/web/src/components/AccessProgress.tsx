// Streamed progress for a physical request (spec §22): the stages in order,
// the one we are at, the real elapsed time and the honest ETA. It appears
// the moment the student confirms — "Checking with the school" covers the
// fresh reads of prepare, so nothing is a black box — and the terminal line
// is the school's answer, or the truthful absence of one.

import { useEffect, useState } from "react";
import type { AccessProgressEvent, ProgressStage } from "@honey/shared/access";
import { elapsedLabel } from "../lib/access/format";
import { useT } from "../lib/i18n";

type Stage = "preparing" | ProgressStage;
const ORDER: Stage[] = ["preparing", "accepted", "sending", "waiting_for_school"];
const STAGE_LABEL: Record<Stage, string> = {
  preparing: "Checking with the school",
  accepted: "Accepted",
  sending: "Sending",
  waiting_for_school: "Waiting for the school",
  confirmed: "Confirmed",
  rejected: "Declined",
  not_sent: "Not sent",
  outcome_unknown: "No answer",
};

export function AccessProgress({
  title,
  events,
  etaLabel,
  startedAt,
  failure,
  onDone,
}: {
  title: string;
  events: AccessProgressEvent[];
  etaLabel: string | null;
  startedAt: number;
  /** A prepare that never became an operation: nothing was sent. */
  failure?: string | null;
  onDone: () => void;
}) {
  const t = useT();
  const last = events[events.length - 1];
  const terminal = last?.terminal ? last : null;
  const settled = !!terminal || !!failure;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (settled) return;
    const id = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(id);
  }, [settled]);
  const elapsed = terminal ? terminal.elapsedMs : now - startedAt;
  const reached = new Set<Stage>(["preparing", ...events.map((e) => e.stage)]);
  const current: Stage = terminal ? terminal.stage : last ? last.stage : "preparing";
  const tone = failure ? "warning" : terminal ? (terminal.stage === "confirmed" ? "ok" : terminal.stage === "outcome_unknown" ? "danger" : "warning") : "live";

  return (
    <section className={`access-progress access-progress--${tone}`} aria-live="polite" aria-label={title}>
      <ol className="access-stages">
        {ORDER.map((stage) => (
          <li key={stage} className={`access-stage${reached.has(stage) ? " access-stage--reached" : ""}${current === stage && !failure ? " access-stage--current" : ""}`}>
            <span className="access-stage__dot" aria-hidden="true" />
            <span>{t(STAGE_LABEL[stage])}</span>
          </li>
        ))}
        {terminal && (
          <li className={`access-stage access-stage--reached access-stage--current access-stage--${terminal.stage}`}>
            <span className="access-stage__dot" aria-hidden="true" />
            <span>{t(STAGE_LABEL[terminal.stage])}</span>
          </li>
        )}
        {failure && (
          <li className="access-stage access-stage--reached access-stage--current access-stage--not_sent">
            <span className="access-stage__dot" aria-hidden="true" />
            <span>{t("Not sent")}</span>
          </li>
        )}
      </ol>
      {settled && tone !== "ok" ? (
        // A failure is unmistakable: a full banner with what happened and, when the school gave a reason, its own words.
        <div role="alert" className={`banner banner--${tone === "danger" ? "danger" : "warning"} access-progress__failure`}>
          <strong className="access-progress__headline">{failure ? t("Not sent") : t(STAGE_LABEL[terminal!.stage])}</strong>
          <span>{failure ? t(failure) : t(terminal!.message)}</span>
          {terminal?.detail && (
            <span className="access-progress__detail">
              {t("The school said:")} “{terminal.detail}”
            </span>
          )}
        </div>
      ) : (
        <p className="access-progress__line">{terminal ? t(terminal.message) : last ? t(last.message) : t("Checking your permit and the gate with the school…")}</p>
      )}
      <p className="caption">
        {elapsedLabel(elapsed)}
        {!settled && etaLabel && ` · ${t(etaLabel)}`}
      </p>
      {settled && (
        <div className="modal__actions">
          <button className="btn btn--primary btn--block" onClick={onDone}>
            {t("Done")}
          </button>
        </div>
      )}
    </section>
  );
}
