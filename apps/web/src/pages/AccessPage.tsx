// Scroll model: FRAMED_SCROLL (§16.14.2).
// /access — Web Access (spec Part II): the gates the school lists, which
// route can open one right now (day student, or an approved unused permit
// inside its window), the student's exit permits, and the physical action
// behind one explicit confirmation. Every line of copy says what is true:
// what was sent, what the school answered, or that it did not answer.

import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { displayReason, displayStatus, isOpenable, openablePermits, permitTone, sortedForList, type AccessBootstrap, type AccessProgressEvent, type Door, type Permit, type PreparedOpenOperation } from "@honey/shared/access";
import { AccessProgress } from "../components/AccessProgress";
import { ConfirmDialog } from "../components/Modal";
import { ChevronRightIcon } from "../components/icons";
import { accessClient, AccessClientError, describeAccessFailure, type AccessFailure } from "../lib/access/client";
import { permitWindow } from "../lib/access/format";
import { useT } from "../lib/i18n";
import { Skeleton } from "../lib/motion";

type Pending = { kind: "open"; door: Door; route: "day_student" | "exit_permit"; permit: Permit | null } | { kind: "withdraw"; permit: Permit };
type Running = { title: string; op: PreparedOpenOperation; events: AccessProgressEvent[]; startedAt: number };

export function AccessPage() {
  const t = useT();
  const [boot, setBoot] = useState<AccessBootstrap | null>(null);
  const [failure, setFailure] = useState<AccessFailure | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [pending, setPending] = useState<Pending | null>(null);
  const [busy, setBusy] = useState(false);
  const [running, setRunning] = useState<Running | null>(null);
  const [now, setNow] = useState(Date.now());

  const reload = useCallback(async () => {
    setFailure(null);
    try {
      setBoot(await accessClient.bootstrap());
      setNow(Date.now());
    } catch (e) {
      setFailure(e instanceof AccessClientError ? e.code : "network");
    }
  }, []);
  useEffect(() => {
    void reload();
  }, [reload]);
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);

  const openable = boot ? openablePermits(boot.permits, now) : [];
  const bestPermit = openable[0] ?? null;
  const route: "day_student" | "exit_permit" | null = boot?.identity.dayStudent ? "day_student" : bestPermit ? "exit_permit" : null;
  const routeLine = !boot
    ? ""
    : route === "day_student"
      ? t("Day student · opens directly")
      : bestPermit
        ? `${t("Exit permit")} · ${displayReason(bestPermit)} · ${permitWindow(bestPermit.start, bestPermit.end, now)}`
        : t("No usable permit right now. An approved permit inside its time window can open a gate.");

  async function start(p: Pending) {
    if (!boot) return;
    setBusy(true);
    setNotice(null);
    try {
      const op = p.kind === "open" ? await accessClient.prepareOpen({ route: p.route, gateKey: p.door.key, ...(p.permit ? { permitRecordId: p.permit.recordId } : {}) }) : await accessClient.prepareWithdraw(p.permit.recordId);
      const title = p.kind === "open" ? `${t("Opening")} ${p.door.displayName}` : t("Withdrawing the request");
      const run: Running = { title, op, events: [], startedAt: Date.now() };
      setRunning(run);
      setPending(null);
      await accessClient.commit(op, (event) => setRunning((r) => (r && r.op.operationId === op.operationId ? { ...r, events: [...r.events, event] } : r)));
    } catch (e) {
      const code = e instanceof AccessClientError ? e.code : "network";
      setNotice(describeAccessFailure(code).text);
      setPending(null);
      setRunning(null);
    } finally {
      setBusy(false);
    }
  }

  function finish() {
    setRunning(null);
    void reload();
  }

  if (running) {
    return (
      <div className="stack access">
        <h1 className="page-title">{t("Access")}</h1>
        <AccessProgress title={running.title} events={running.events} etaLabel={running.op.etaLabel} startedAt={running.startedAt} onDone={finish} />
      </div>
    );
  }

  return (
    <div className="stack access">
      <h1 className="page-title">{t("Access")}</h1>

      {failure && <FailureBanner code={failure} onRetry={() => void reload()} />}
      {notice && (
        <div role="alert" className="banner banner--warning">
          {t(notice)}
        </div>
      )}
      {boot && !boot.enabled && (
        <div className="banner banner--warning">{t("Web Access is paused. You can look, but nothing can be opened from here right now.")}</div>
      )}

      {!boot && !failure && (
        <div className="card">
          <Skeleton lines={3} />
        </div>
      )}

      {boot && (
        <>
          <section className="card" aria-label={t("Gates")}>
            <h2 className="section-title">{t("Gates")}</h2>
            {!boot.doorsFresh && <p className="caption">{t("The gate list couldn't be read just now.")}</p>}
            <div className="rowlist">
              {boot.doors.map((door) => (
                <div className="row" key={door.key}>
                  <div className="row__main">
                    <span className="row__title">{door.displayName}</span>
                  </div>
                  <button className="btn btn--primary btn--small" disabled={!boot.enabled || !route || busy} onClick={() => setPending({ kind: "open", door, route: route!, permit: route === "exit_permit" ? bestPermit : null })}>
                    {t("Open")}
                  </button>
                </div>
              ))}
              {boot.doors.length === 0 && boot.doorsFresh && <p className="caption">{t("The school lists no gates for your account.")}</p>}
            </div>
            <p className="caption access-route">{routeLine}</p>
            <p className="caption">{t(boot.eta.openGate)}</p>
          </section>

          <section className="card" aria-label={t("Exit permits")}>
            <h2 className="section-title">{t("Exit permits")}</h2>
            {!boot.permitsFresh && <p className="caption">{t("Your permits couldn't be read just now.")}</p>}
            <div className="rowlist">
              {sortedForList(boot.permits).map((p) => (
                <PermitRow key={p.recordId} permit={p} now={now} disabled={!boot.enabled || busy} onWithdraw={() => setPending({ kind: "withdraw", permit: p })} />
              ))}
              {boot.permits.length === 0 && boot.permitsFresh && <p className="caption">{t("No exit permits yet.")}</p>}
            </div>
            <Link to="/access/permits/new" className="row row--actions access-new-permit" aria-disabled={!boot.enabled}>
              <span className="row__main">
                <span className="row__title">{t("Request an exit permit")}</span>
                <span className="row__sub">{t(boot.eta.permit)}</span>
              </span>
              <ChevronRightIcon />
            </Link>
          </section>
        </>
      )}

      {pending?.kind === "open" && (
        <ConfirmDialog
          title={`${t("Open")} ${pending.door.displayName}?`}
          body={`${pending.route === "day_student" ? t("Day student") : `${t("Exit permit")} · ${displayReason(pending.permit!)}`}. ${t("This sends a physical gate request.")}`}
          confirmLabel={t("Open")}
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void start(pending)}
        />
      )}
      {pending?.kind === "withdraw" && (
        <ConfirmDialog
          title={t("Withdraw this request?")}
          body={`${displayReason(pending.permit)} · ${permitWindow(pending.permit.start, pending.permit.end, now)}. ${t("This tells the school to delete the pending request.")}`}
          confirmLabel={t("Withdraw")}
          danger
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void start(pending)}
        />
      )}
    </div>
  );
}

function PermitRow({ permit, now, disabled, onWithdraw }: { permit: Permit; now: number; disabled: boolean; onWithdraw: () => void }) {
  const t = useT();
  const tone = permitTone(permit, now);
  const openableNow = isOpenable(permit, now);
  return (
    <div className={`row row--stack access-permit access-permit--${tone}`}>
      <div className="row__main">
        <span className="row__title">
          {displayReason(permit)}
          {openableNow && <span className="chip chip--ok access-permit__now">{t("Can open now")}</span>}
        </span>
        <span className="row__sub">{permitWindow(permit.start, permit.end, now)}</span>
      </div>
      <div className="row__actions">
        <span className={`chip chip--${tone === "ok" ? "ok" : tone === "danger" ? "danger" : "muted"}`}>{t(displayStatus(permit))}</span>
        {permit.state === "pending" && (
          <button className="btn btn--ghost btn--small" disabled={disabled} onClick={onWithdraw}>
            {t("Withdraw")}
          </button>
        )}
      </div>
    </div>
  );
}

function FailureBanner({ code, onRetry }: { code: AccessFailure; onRetry: () => void }) {
  const t = useT();
  const d = describeAccessFailure(code);
  return (
    <div role="alert" className="banner banner--danger access-failure">
      <span>{t(d.text)}</span>
      {d.reconnect ? (
        <Link to="/settings/connection" className="btn btn--ghost btn--small">
          {t("School connection")}
        </Link>
      ) : (
        <button className="btn btn--ghost btn--small" onClick={onRetry}>
          {t("Try again")}
        </button>
      )}
    </div>
  );
}
