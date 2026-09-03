// Scroll model: FRAMED_SCROLL (§16.14.2).
// /access — Web Access (spec Part II), laid out as the iPhone's Access
// screen: the apply-for-a-permit card, the permits list (status chip, Choose
// gate for an openable one, withdraw for a pending one), then the "School
// access" dock — Day student · Exit permit — which opens the gate picker
// (every gate the school lists) and one explicit confirmation before the
// physical request. The last bootstrap is shown at once while a fresh one
// loads; physical authority always comes from a fresh prepare.

import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { displayReason, displayStatus, isOpenable, openablePermits, permitTone, quickPermitDraft, sortedForList, type AccessBootstrap, type AccessProgressEvent, type AccessRouteKind, type Door, type Permit, type PreparedOpenOperation } from "@honey/shared/access";
import { AccessProgress } from "../components/AccessProgress";
import { ConfirmDialog, Modal } from "../components/Modal";
import { accessClient, AccessClientError, describeAccessFailure, type AccessFailure } from "../lib/access/client";
import { ChevronRightIcon } from "../components/icons";
import { permitWindow, permitWindowFromTimes, toTimeInput } from "../lib/access/format";
import { useT } from "../lib/i18n";
import { Skeleton } from "../lib/motion";

type Route = { kind: AccessRouteKind; permit: Permit | null };
type Pending = { kind: "open"; door: Door; route: Route } | { kind: "withdraw"; permit: Permit } | { kind: "apply"; startTime: string; endTime: string; note: string };
type Running = { title: string; op: PreparedOpenOperation; events: AccessProgressEvent[]; startedAt: number };

const COLLAPSED_PERMITS = 3;
const FOLD_KEY = "honey.access.permitsOpen";

/** The permits fold: closed by default (the first screen holds everything); remembered per device. */
function readFold(): boolean {
  try {
    return localStorage.getItem(FOLD_KEY) === "open";
  } catch {
    return false;
  }
}

export function AccessPage() {
  const t = useT();
  const [boot, setBoot] = useState<AccessBootstrap | null>(() => accessClient.cachedBootstrap());
  const [refreshing, setRefreshing] = useState(false);
  const [failure, setFailure] = useState<AccessFailure | null>(null);
  const [notice, setNotice] = useState<{ tone: "warning" | "success"; text: string } | null>(null);
  const [pickGate, setPickGate] = useState<Route | null>(null);
  const [choosePermit, setChoosePermit] = useState(false);
  const [pending, setPending] = useState<Pending | null>(null);
  const [busy, setBusy] = useState(false);
  const [running, setRunning] = useState<Running | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [permitsOpen, setPermitsOpenState] = useState(() => readFold());
  const setPermitsOpen = (update: (v: boolean) => boolean) =>
    setPermitsOpenState((v) => {
      const next = update(v);
      try {
        localStorage.setItem(FOLD_KEY, next ? "open" : "closed");
      } catch {
        /* per-device convenience only */
      }
      return next;
    });
  const [now, setNow] = useState(Date.now());

  const reload = useCallback(async () => {
    setFailure(null);
    setRefreshing(true);
    try {
      setBoot(await accessClient.bootstrap());
      setNow(Date.now());
    } catch (e) {
      setFailure(e instanceof AccessClientError ? e.code : "network");
    } finally {
      setRefreshing(false);
    }
  }, []);
  useEffect(() => {
    void reload();
  }, [reload]);
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(id);
  }, []);

  const permits = boot ? sortedForList(boot.permits) : [];
  const openable = boot ? openablePermits(boot.permits, now) : [];
  const enabled = boot?.enabled ?? false;
  const canAct = enabled && !busy;
  const visiblePermits = showAll ? permits : permits.slice(0, COLLAPSED_PERMITS);

  const permitSubtitle = !boot
    ? t("Checking permits…")
    : !boot.permitsFresh
      ? t("Refresh to use a permit")
      : openable.length === 0
        ? t("No permit usable right now")
        : openable.length === 1
          ? t("Use the approved permit")
          : `${t("Choose one of")} ${openable.length} ${t("permits")}`;

  function beginGateFlow(route: Route) {
    if (!boot || !boot.doorsFresh || boot.doors.length === 0) {
      setNotice({ tone: "warning", text: t("Gate names are unavailable. Refresh Access and try again.") });
      return;
    }
    setPickGate(route);
  }

  function beginPermitSelection() {
    if (!boot?.permitsFresh) {
      setNotice({ tone: "warning", text: t("Permits are not available yet. Refresh Access and try again.") });
      return;
    }
    if (openable.length === 0) {
      setNotice({ tone: "warning", text: t("No approved, unused exit permit covers right now. Apply for one first.") });
      return;
    }
    if (openable.length === 1) beginGateFlow({ kind: "exit_permit", permit: openable[0]! });
    else setChoosePermit(true);
  }

  async function start(p: Pending) {
    setBusy(true);
    setNotice(null);
    try {
      let op: PreparedOpenOperation;
      let title: string;
      if (p.kind === "open") {
        op = await accessClient.prepareOpen({ route: p.route.kind, gateKey: p.door.key, ...(p.route.permit ? { permitRecordId: p.route.permit.recordId } : {}) });
        title = `${t("Opening")} ${p.door.displayName}`;
      } else if (p.kind === "withdraw") {
        op = await accessClient.prepareWithdraw(p.permit.recordId);
        title = t("Withdrawing the request");
      } else {
        op = await accessClient.preparePermit({ startTime: p.startTime, endTime: p.endTime, note: p.note });
        title = t("Applying for a permit");
      }
      setPending(null);
      setRunning({ title, op, events: [], startedAt: Date.now() });
      await accessClient.commit(op, (event) => setRunning((r) => (r && r.op.operationId === op.operationId ? { ...r, events: [...r.events, event] } : r)));
    } catch (e) {
      setNotice({ tone: "warning", text: describeAccessFailure(e instanceof AccessClientError ? e.code : "network").text });
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
      <div className="page-head page-head--tools">
        <h1 className="page-title">{t("Access")}</h1>
        <button className="iconbtn" aria-label={t("Refresh Access")} disabled={refreshing} onClick={() => void reload()}>
          <RefreshIcon />
        </button>
      </div>

      {failure && <FailureBanner code={failure} onRetry={() => void reload()} />}
      {notice && (
        <div role="alert" className={`banner banner--${notice.tone}`}>
          {t(notice.text)}
        </div>
      )}
      {boot && !enabled && <div className="banner banner--warning">{t("Web Access is paused. You can look, but nothing can be opened from here right now.")}</div>}

      {!boot && !failure && (
        <div className="card">
          <Skeleton lines={4} />
        </div>
      )}

      {boot && (
        <>
          <ApplyCard disabled={!canAct} onApply={(d) => setPending({ kind: "apply", ...d })} etaLabel={boot.eta.permit} />

          <section className="access-section" aria-label={t("Permits")}>
            {/* The header row is the fold: collapsed by default so the whole screen fits without scrolling. */}
            <button className="access-fold" aria-expanded={permitsOpen} onClick={() => setPermitsOpen((v) => !v)}>
              <h2 className="overline">{t("Permits")}</h2>
              <span className="access-fold__summary">
                {boot.permitsFresh ? (openable.length > 0 ? `${openable.length} ${t("usable now")} · ${permits.length}` : `${permits.length}`) : t("unavailable")}
              </span>
              <span className={`access-fold__chevron${permitsOpen ? " is-open" : ""}`} aria-hidden="true">
                <ChevronRightIcon />
              </span>
            </button>
            {permitsOpen && (
              <>
                {!boot.permitsFresh && (
                  <div className="banner banner--warning">{t("The permit list could not be refreshed. It may be out of date and cannot open a gate until it is refreshed.")}</div>
                )}
                {visiblePermits.length === 0 ? (
                  <p className="caption">{boot.permitsFresh ? t("No permits.") : t("Permits unavailable.")}</p>
                ) : (
                  <div className="rowlist">
                    {visiblePermits.map((p) => (
                      <PermitRow key={p.recordId} permit={p} now={now} actionable={canAct && boot.permitsFresh} onChooseGate={() => beginGateFlow({ kind: "exit_permit", permit: p })} onWithdraw={() => setPending({ kind: "withdraw", permit: p })} />
                    ))}
                  </div>
                )}
                {permits.length > COLLAPSED_PERMITS && (
                  <button className="btn btn--ghost btn--small" onClick={() => setShowAll((v) => !v)}>
                    {showAll ? t("Show fewer") : `${t("Show all")} ${permits.length} ${t("permits")}`}
                  </button>
                )}
              </>
            )}
          </section>

          <section className="access-section" aria-label={t("School access")}>
            <div className="access-dock__head">
              <h2 className="overline">{t("School access")}</h2>
              <span className="access-dock__note">{t("Sent directly to the school")}</span>
            </div>
            <div className="access-dock">
              <button className="access-action" disabled={!canAct || !boot.identity.dayStudent} onClick={() => beginGateFlow({ kind: "day_student", permit: null })}>
                <span className="access-action__glyph" aria-hidden="true">
                  <WalkIcon />
                </span>
                <span className="access-action__text">
                  <span className="access-action__title">{t("Day student")}</span>
                  <span className="access-action__sub">{boot.identity.dayStudent ? t("Open without an exit permit") : t("Not a day-student account")}</span>
                </span>
              </button>
              <button className="access-action" disabled={!canAct} onClick={beginPermitSelection}>
                <span className="access-action__glyph" aria-hidden="true">
                  <DocIcon />
                </span>
                <span className="access-action__text">
                  <span className="access-action__title">{t("Exit permit")}</span>
                  <span className="access-action__sub">{permitSubtitle}</span>
                </span>
              </button>
            </div>
            <p className="caption">{t(boot.eta.openGate)}</p>
          </section>
        </>
      )}

      {pickGate && boot && (
        <Modal title={t("Choose gate")} onClose={() => setPickGate(null)}>
          <p className="overline">{pickGate.kind === "day_student" ? t("Day student access") : t("Exit permit access")}</p>
          <div className="rowlist">
            {boot.doors.map((door) => (
              <button
                key={door.key}
                className="row row--actions"
                onClick={() => {
                  setPickGate(null);
                  setPending({ kind: "open", door, route: pickGate });
                }}
              >
                <span className="row__main">
                  <span className="row__title">{door.displayName}</span>
                </span>
              </button>
            ))}
          </div>
          <p className="caption">{t("You will confirm before the gate opens.")}</p>
        </Modal>
      )}

      {choosePermit && (
        <Modal title={t("Choose permit")} onClose={() => setChoosePermit(false)}>
          <p className="caption">{t("Select the permit to use for this gate opening.")}</p>
          <div className="rowlist">
            {openable.map((p) => (
              <button
                key={p.recordId}
                className="row row--actions"
                onClick={() => {
                  setChoosePermit(false);
                  beginGateFlow({ kind: "exit_permit", permit: p });
                }}
              >
                <span className="row__main">
                  <span className="row__title">{displayReason(p)}</span>
                  <span className="row__sub">{permitWindow(p.start, p.end, now)}</span>
                </span>
              </button>
            ))}
          </div>
        </Modal>
      )}

      {pending?.kind === "open" && (
        <ConfirmDialog
          title={`${t("Open")} ${pending.door.displayName}?`}
          body={`${pending.route.kind === "day_student" ? t("Day student") : `${t("Exit permit")} · ${displayReason(pending.route.permit!)}`}. ${t("This opens a physical gate. Only do this when you are there.")}`}
          confirmLabel={`${t("Open")} ${pending.door.displayName}`}
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void start(pending)}
        />
      )}
      {pending?.kind === "withdraw" && (
        <ConfirmDialog
          title={t("Withdraw this permit request?")}
          body={`${displayReason(pending.permit)} · ${permitWindow(pending.permit.start, pending.permit.end, now)}. ${t("The request is deleted on the school portal. You can apply again any time.")}`}
          confirmLabel={t("Withdraw request")}
          danger
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void start(pending)}
        />
      )}
      {pending?.kind === "apply" && (
        <ConfirmDialog
          title={t("Apply for this permit?")}
          body={`${pending.startTime.slice(0, 16)} → ${pending.endTime.slice(0, 16)} · ${pending.note}. ${t("This sends a request to the school.")}`}
          confirmLabel={t("Apply for permit")}
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void start(pending)}
        />
      )}
    </div>
  );
}

/**
 * The iPhone's apply card, compact: the date stays on today, start · end as
 * times on one row (an end at or before the start counts as tomorrow, "+1"),
 * then reason and the Apply button on the next. Quick default: now → +2 h, 出门.
 */
function ApplyCard({ disabled, onApply, etaLabel }: { disabled: boolean; onApply: (d: { startTime: string; endTime: string; note: string }) => void; etaLabel: string }) {
  const t = useT();
  const [draft] = useState(() => quickPermitDraft(Date.now()));
  const [start, setStart] = useState(toTimeInput(draft.start));
  const [end, setEnd] = useState(toTimeInput(draft.end));
  const [reason, setReason] = useState(draft.reason);
  const window = permitWindowFromTimes(start, end, Date.now());
  return (
    <form
      className="card access-apply"
      onSubmit={(e) => {
        e.preventDefault();
        if (window) onApply({ startTime: window.startTime, endTime: window.endTime, note: reason.trim() || "出门" });
      }}
    >
      <div className="access-apply__head">
        <h2 className="section-title">{t("Apply for a permit")}</h2>
        <span className="caption">
          {t("Today")} · {t(etaLabel)}
        </span>
      </div>
      <div className="access-apply__row">
        <label className="field access-apply__time">
          <span className="field__label">{t("Start")}</span>
          <input className="input" type="time" value={start} onChange={(e) => setStart(e.target.value)} required />
        </label>
        <label className="field access-apply__time">
          <span className="field__label">
            {t("End")}
            {window?.crossesMidnight && <span className="chip chip--muted access-apply__badge">+1</span>}
          </span>
          <input className="input" type="time" value={end} onChange={(e) => setEnd(e.target.value)} required />
        </label>
      </div>
      <div className="access-apply__row access-apply__row--reason">
        <label className="field">
          <span className="field__label">{t("Reason")}</span>
          <input className="input" type="text" value={reason} maxLength={60} placeholder="出门" onChange={(e) => setReason(e.target.value)} />
        </label>
        <button className="btn btn--primary access-apply__submit" type="submit" disabled={disabled || !window}>
          {t("Apply")}
        </button>
      </div>
    </form>
  );
}

function PermitRow({ permit, now, actionable, onChooseGate, onWithdraw }: { permit: Permit; now: number; actionable: boolean; onChooseGate: () => void; onWithdraw: () => void }) {
  const t = useT();
  const tone = permitTone(permit, now);
  const openableNow = actionable && isOpenable(permit, now);
  return (
    <div className={`row row--stack access-permit access-permit--${tone}`}>
      <div className="row__main">
        <span className="row__title">{displayReason(permit)}</span>
        <span className="row__sub">{permitWindow(permit.start, permit.end, now)}</span>
      </div>
      <div className="row__actions access-permit__actions">
        <span className={`chip chip--${tone === "ok" ? "ok" : tone === "danger" ? "danger" : "muted"}`}>{t(displayStatus(permit))}</span>
        {openableNow && (
          <button className="btn btn--primary btn--small" onClick={onChooseGate}>
            {t("Choose gate")}
          </button>
        )}
        {permit.state === "pending" && (
          <button className="btn btn--ghost btn--small" disabled={!actionable} onClick={onWithdraw}>
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

function RefreshIcon() {
  return (
    <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M20 12a8 8 0 1 1-2.35-5.65" />
      <path d="M20 4v5h-5" />
    </svg>
  );
}

function WalkIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="13" cy="4.5" r="1.6" />
      <path d="M10.5 21l1.8-6.2-2.3-2.1 1.4-5.2 3.1 1.4 2.6 2.2M9.4 9.5 6.5 11.8l-1 4.2M14.5 15.3l2.6 5.2" />
    </svg>
  );
}

function DocIcon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M7 3.5h7l4 4V20a.5.5 0 0 1-.5.5h-11A.5.5 0 0 1 6 20V4a.5.5 0 0 1 .5-.5Z" />
      <path d="M14 3.5V8h4M9 12h6M9 15.5h6" />
    </svg>
  );
}
