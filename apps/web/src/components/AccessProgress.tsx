// Streamed progress for a physical request (spec §22): the stages in order,
// the one we are at, the real elapsed time and the honest ETA. The terminal
// line is the school's answer — or the truthful absence of one.

import { useEffect, useState } from "react";
import type { AccessProgressEvent, ProgressStage } from "@honey/shared/access";
import { elapsedLabel } from "../lib/access/format";
import { useT } from "../lib/i18n";

const ORDER: ProgressStage[] = ["accepted", "sending", "waiting_for_school"];
const STAGE_LABEL: Record<ProgressStage, string> = {
  accepted: "Accepted",
  sending: "Sending",
  waiting_for_school: "Waiting for the school",
  confirmed: "Confirmed",
  rejected: "Declined",
  not_sent: "Not sent",
  outcome_unknown: "No answer",
};

export function AccessProgress({ title, events, etaLabel, startedAt, onDone }: { title: string; events: AccessProgressEvent[]; etaLabel: string; startedAt: number; onDone: () => void }) {
  const t = useT();
  const last = events[events.length - 1];
  const terminal = last?.terminal ? last : null;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (terminal) return;
    const id = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(id);
  }, [terminal]);
  const elapsed = terminal ? terminal.elapsedMs : now - startedAt;
  const reached = new Set(events.map((e) => e.stage));
  const tone = terminal ? (terminal.stage === "confirmed" ? "ok" : terminal.stage === "outcome_unknown" ? "danger" : "warning") : "live";

  return (
    <section className={`card access-progress access-progress--${tone}`} aria-live="polite" aria-label={title}>
      <h2 className="section-title">{title}</h2>
      <ol className="access-stages">
        {ORDER.map((stage) => (
          <li key={stage} className={`access-stage${reached.has(stage) ? " access-stage--reached" : ""}${last?.stage === stage ? " access-stage--current" : ""}`}>
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
      </ol>
      <p className="access-progress__line">{terminal ? t(terminal.message) : last ? t(last.message) : t("Starting…")}</p>
      <p className="caption">
        {elapsedLabel(elapsed)}
        {!terminal && ` · ${t(etaLabel)}`}
      </p>
      {terminal && (
        <div className="card-actions">
          <button className="btn btn--primary" onClick={onDone}>
            {t("Done")}
          </button>
        </div>
      )}
    </section>
  );
}
