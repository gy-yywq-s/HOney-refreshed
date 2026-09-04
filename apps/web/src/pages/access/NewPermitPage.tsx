// Scroll model: FRAMED_SCROLL (§16.14.2).
// /access/permits/new — request an exit permit: the portal's quick default
// (now → +2 h, reason 出门) prefilled, times in the school's zone, one
// confirmation, then the same streamed truth as a gate request.

import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { quickPermitDraft, type AccessProgressEvent, type PreparedOpenOperation } from "@honey/shared/access";
import { AccessProgress } from "../../components/AccessProgress";
import { ConfirmDialog } from "../../components/Modal";
import { accessClient, AccessClientError, describeAccessFailure } from "../../lib/access/client";
import { fromLocalInput, toLocalInput } from "../../lib/access/format";
import { useT } from "../../lib/i18n";

export function NewPermitPage() {
  const t = useT();
  const navigate = useNavigate();
  const draft = quickPermitDraft(Date.now());
  const [start, setStart] = useState(toLocalInput(draft.start));
  const [end, setEnd] = useState(toLocalInput(draft.end));
  const [reason, setReason] = useState(draft.reason);
  const [notice, setNotice] = useState<string | null>(null);
  const [prepared, setPrepared] = useState<PreparedOpenOperation | null>(null);
  const [busy, setBusy] = useState(false);
  const [running, setRunning] = useState<{ op: PreparedOpenOperation; events: AccessProgressEvent[]; startedAt: number } | null>(null);

  const startWire = fromLocalInput(start);
  const endWire = fromLocalInput(end);
  const valid = !!startWire && !!endWire && endWire > startWire && reason.trim().length > 0;

  async function prepare() {
    if (!startWire || !endWire) return;
    setBusy(true);
    setNotice(null);
    try {
      setPrepared(await accessClient.preparePermit({ startTime: startWire, endTime: endWire, note: reason.trim() }));
    } catch (e) {
      setNotice(describeAccessFailure(e instanceof AccessClientError ? e.code : "network").text);
    } finally {
      setBusy(false);
    }
  }

  async function send() {
    if (!prepared) return;
    const op = prepared;
    setBusy(true);
    const run = { op, events: [] as AccessProgressEvent[], startedAt: Date.now() };
    setRunning(run);
    setPrepared(null);
    try {
      await accessClient.commit(op, (event) => setRunning((r) => (r ? { ...r, events: [...r.events, event] } : r)));
    } catch (e) {
      setNotice(describeAccessFailure(e instanceof AccessClientError ? e.code : "network").text);
      setRunning(null);
    } finally {
      setBusy(false);
    }
  }

  if (running) {
    return (
      <div className="stack access">
        <h1 className="page-title">{t("Request an exit permit")}</h1>
        <AccessProgress title={t("Sending the request")} events={running.events} etaLabel={running.op.etaLabel} startedAt={running.startedAt} onDone={() => navigate("/access", { replace: true })} />
      </div>
    );
  }

  return (
    <div className="stack access">
      <h1 className="page-title">{t("Request an exit permit")}</h1>
      {notice && (
        <div role="alert" className="banner banner--warning">
          {t(notice)}
        </div>
      )}
      <form
        className="card stack"
        onSubmit={(e) => {
          e.preventDefault();
          void prepare();
        }}
      >
        <label className="field">
          <span className="field__label">{t("From")}</span>
          <input className="input" type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} required />
        </label>
        <label className="field">
          <span className="field__label">{t("Until")}</span>
          <input className="input" type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} required />
        </label>
        <label className="field">
          <span className="field__label">{t("Reason")}</span>
          <input className="input" type="text" value={reason} maxLength={60} onChange={(e) => setReason(e.target.value)} required />
        </label>
        <p className="caption">{t("Times are the school's clock (Shanghai). The request goes to the school for approval.")}</p>
        <div className="card-actions">
          <button className="btn btn--primary" type="submit" disabled={!valid || busy}>
            {t("Continue")}
          </button>
        </div>
      </form>

      {prepared && (
        <ConfirmDialog
          title={t("Send this permit request?")}
          body={`${start.replace("T", " ")} → ${end.replace("T", " ")} · ${reason.trim()}. ${t("This sends a request to the school.")}`}
          confirmLabel={t("Send")}
          busy={busy}
          onClose={() => setPrepared(null)}
          onConfirm={() => void send()}
        />
      )}
    </div>
  );
}
