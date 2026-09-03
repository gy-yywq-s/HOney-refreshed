// Scroll model: FRAMED_SCROLL (§16.14.2).
// /access — Web Access (spec Part II), laid out as the iPhone's Access
// screen: the apply-for-a-permit card, the permits fold (status chip, Choose
// gate for an openable one, withdraw for a pending one), then the "School
// access" dock — Day student · Exit permit. Every physical action runs in
// ONE sheet: choose (permit →) gate → confirm → progress; the progress view
// appears the instant the student confirms, and the sheet cannot be
// dismissed while the school is being asked. The last bootstrap is shown
// at once while a fresh one loads; physical authority always comes from a
// fresh prepare.

import { useCallback, useEffect, useLayoutEffect, useRef, useState, type RefObject } from "react";
import { Link } from "react-router-dom";
import { displayReason, displayStatus, isOpenable, openablePermits, permitTone, quickPermitDraft, sortedForList, type AccessBootstrap, type AccessProgressEvent, type AccessRouteKind, type Door, type Permit, type PreparedOpenOperation } from "@honey/shared/access";
import { AccessProgress } from "../components/AccessProgress";
import { Modal } from "../components/Modal";
import { ChevronRightIcon } from "../components/icons";
import { accessClient, AccessClientError, describeAccessFailure, type AccessFailure } from "../lib/access/client";
import { permitWindow, permitWindowFromTimes, toTimeInput } from "../lib/access/format";
import { useT } from "../lib/i18n";
import { Skeleton } from "../lib/motion";

type Route = { kind: AccessRouteKind; permit: Permit | null };
type Action = { kind: "open"; route: Route; door: Door | null } | { kind: "withdraw"; permit: Permit } | { kind: "apply"; startTime: string; endTime: string; note: string };
type Step = "permit" | "gate" | "confirm" | "running";
interface Flow {
  action: Action;
  step: Step;
  /** The run, from the moment Confirm was pressed. */
  run?: { startedAt: number; op: PreparedOpenOperation | null; events: AccessProgressEvent[]; failure: string | null };
}

const COLLAPSED_PERMITS = 3;
const FOLD_KEY = "honey.access.permitsOpen";

/** The permits fold: open by default (the list takes exactly the space that fits); remembered per device. */
function readFold(): boolean {
  try {
    return localStorage.getItem(FOLD_KEY) !== "closed";
  } catch {
    return true;
  }
}

/**
 * How many permit rows fit between the apply card and the dock on THIS
 * phone: the list body is measured, and the count re-derives on resize.
 */
function useRowsThatFit(active: boolean, total: number): { bodyRef: RefObject<HTMLDivElement>; fit: number | null } {
  const bodyRef = useRef<HTMLDivElement>(null);
  const [fit, setFit] = useState<number | null>(null);
  useLayoutEffect(() => {
    const body = bodyRef.current;
    if (!active || !body) {
      setFit(null);
      return;
    }
    const measure = () => {
      const row = body.querySelector<HTMLElement>(".access-permit");
      if (!row) return;
      const rowH = row.getBoundingClientRect().height;
      const list = body.querySelector<HTMLElement>(".rowlist");
      const gap = list ? parseFloat(getComputedStyle(list).rowGap || "0") || 0 : 0;
      const available = body.clientHeight;
      const n = Math.max(1, Math.floor((available + gap) / (rowH + gap)));
      setFit(Math.min(n, total));
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(body);
    return () => ro.disconnect();
  }, [active, total]);
  return { bodyRef, fit };
}

export function AccessPage() {
  const t = useT();
  const [boot, setBoot] = useState<AccessBootstrap | null>(() => accessClient.cachedBootstrap());
  const [refreshing, setRefreshing] = useState(false);
  const [failure, setFailure] = useState<AccessFailure | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [flow, setFlow] = useState<Flow | null>(null);
  const [showAll, setShowAll] = useState(false);
  const [permitsOpen, setPermitsOpenState] = useState(() => readFold());
  const [now, setNow] = useState(Date.now());
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
  const canAct = enabled && !flow;
  // Fit mode: the open fold shows exactly the rows that fit above the dock; Show all lets the page scroll.
  const fitMode = !!boot && permitsOpen && !showAll;
  const { bodyRef, fit } = useRowsThatFit(fitMode, permits.length);
  const visiblePermits = showAll ? permits : permits.slice(0, fitMode ? (fit ?? COLLAPSED_PERMITS) : COLLAPSED_PERMITS);

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
      setNotice(t("Gate names are unavailable. Refresh Access and try again."));
      return;
    }
    setNotice(null);
    setFlow({ action: { kind: "open", route, door: null }, step: "gate" });
  }

  function beginPermitSelection() {
    if (!boot?.permitsFresh) {
      setNotice(t("Permits are not available yet. Refresh Access and try again."));
      return;
    }
    if (openable.length === 0) {
      setNotice(t("No approved, unused exit permit covers right now. Apply for one first."));
      return;
    }
    if (openable.length === 1) beginGateFlow({ kind: "exit_permit", permit: openable[0]! });
    else {
      setNotice(null);
      setFlow({ action: { kind: "open", route: { kind: "exit_permit", permit: null }, door: null }, step: "permit" });
    }
  }

  /** Confirm pressed: the progress view takes over at once; prepare + commit follow. */
  async function run(action: Action) {
    const startedAt = Date.now();
    setFlow({ action, step: "running", run: { startedAt, op: null, events: [], failure: null } });
    const patch = (update: (r: NonNullable<Flow["run"]>) => NonNullable<Flow["run"]>) => setFlow((f) => (f && f.run ? { ...f, run: update(f.run) } : f));
    try {
      let op: PreparedOpenOperation;
      if (action.kind === "open") {
        op = await accessClient.prepareOpen({ route: action.route.kind, gateKey: action.door!.key, ...(action.route.permit ? { permitRecordId: action.route.permit.recordId } : {}) });
      } else if (action.kind === "withdraw") {
        op = await accessClient.prepareWithdraw(action.permit.recordId);
      } else {
        op = await accessClient.preparePermit({ startTime: action.startTime, endTime: action.endTime, note: action.note });
      }
      patch((r) => ({ ...r, op }));
      await accessClient.commit(op, (event) => patch((r) => ({ ...r, events: [...r.events, event] })));
    } catch (e) {
      const code = e instanceof AccessClientError ? e.code : "network";
      patch((r) => ({ ...r, failure: describeAccessFailure(code).text }));
    }
  }

  function finish() {
    setFlow(null);
    void reload();
  }

  return (
    <div className={fitMode ? "stack access access--fit" : "stack access"}>
      <div className="page-head page-head--tools">
        <h1 className="page-title">{t("Access")}</h1>
        <button className="iconbtn" aria-label={t("Refresh Access")} disabled={refreshing} onClick={() => void reload()}>
          <RefreshIcon />
        </button>
      </div>

      {failure && <FailureBanner code={failure} onRetry={() => void reload()} />}
      {notice && (
        <div role="alert" className="banner banner--warning">
          {t(notice)}
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
          <ApplyCard disabled={!canAct} onApply={(d) => setFlow({ action: { kind: "apply", ...d }, step: "confirm" })} etaLabel={boot.eta.permit} />

          <section className="access-section" aria-label={t("Permits")}>
            {/* The header row is the fold: collapsed by default so the whole screen fits without scrolling. */}
            <div className="access-fold">
              <button className="access-fold__toggle" aria-expanded={permitsOpen} onClick={() => setPermitsOpen((v) => !v)}>
                <h2 className="overline">{t("Permits")}</h2>
                <span className="access-fold__summary">
                  {boot.permitsFresh ? (openable.length > 0 ? `${openable.length} ${t("usable now")} · ${permits.length}` : `${permits.length}`) : t("unavailable")}
                </span>
                <span className={`access-fold__chevron${permitsOpen ? " is-open" : ""}`} aria-hidden="true">
                  <ChevronRightIcon />
                </span>
              </button>
              {/* Show all / fewer lives in the header row so it is never clipped by the fitted list. */}
              {permitsOpen && (permits.length > visiblePermits.length || showAll) && (
                <button className="btn btn--ghost btn--small access-fold__more" onClick={() => setShowAll((v) => !v)}>
                  {showAll ? t("Show fewer") : `${t("Show all")} ${permits.length}`}
                </button>
              )}
            </div>
            {permitsOpen && (
              <div className="access-permits__body" ref={bodyRef}>
                {!boot.permitsFresh && (
                  <div className="banner banner--warning">{t("The permit list could not be refreshed. It may be out of date and cannot open a gate until it is refreshed.")}</div>
                )}
                {visiblePermits.length === 0 ? (
                  <p className="caption">{boot.permitsFresh ? t("No permits.") : t("Permits unavailable.")}</p>
                ) : (
                  <div className="rowlist">
                    {visiblePermits.map((p) => (
                      <PermitRow key={p.recordId} permit={p} now={now} actionable={canAct && boot.permitsFresh} onChooseGate={() => beginGateFlow({ kind: "exit_permit", permit: p })} onWithdraw={() => setFlow({ action: { kind: "withdraw", permit: p }, step: "confirm" })} />
                    ))}
                  </div>
                )}
              </div>
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

      {flow && boot && (
        <FlowSheet
          flow={flow}
          doors={boot.doors}
          openable={openable}
          now={now}
          etaLabel={flow.action.kind === "open" ? boot.eta.openGate : boot.eta.permit}
          onStep={(next) => setFlow(next)}
          onConfirm={() => void run(flow.action)}
          onClose={() => setFlow(null)}
          onDone={finish}
        />
      )}
    </div>
  );
}

/** The one sheet a physical action lives in: permit → gate → confirm → progress. */
function FlowSheet({ flow, doors, openable, now, etaLabel, onStep, onConfirm, onClose, onDone }: { flow: Flow; doors: Door[]; openable: Permit[]; now: number; etaLabel: string; onStep: (next: Flow) => void; onConfirm: () => void; onClose: () => void; onDone: () => void }) {
  const t = useT();
  const { action, step } = flow;
  const running = step === "running";
  const settled = !!flow.run && (!!flow.run.failure || !!flow.run.events.at(-1)?.terminal);

  const title = (() => {
    if (step === "permit") return t("Choose permit");
    if (step === "gate") return t("Choose gate");
    if (action.kind === "open") return running ? `${t("Opening")} ${action.door?.displayName ?? ""}` : `${t("Open")} ${action.door?.displayName ?? ""}?`;
    if (action.kind === "withdraw") return running ? t("Withdrawing the request") : t("Withdraw this permit request?");
    return running ? t("Applying for a permit") : t("Apply for this permit?");
  })();

  const confirmBody = (() => {
    if (action.kind === "open") return `${action.route.kind === "day_student" ? t("Day student") : `${t("Exit permit")} · ${displayReason(action.route.permit!)}`}. ${t("This opens a physical gate. Only do this when you are there.")}`;
    if (action.kind === "withdraw") return `${displayReason(action.permit)} · ${permitWindow(action.permit.start, action.permit.end, now)}. ${t("The request is deleted on the school portal. You can apply again any time.")}`;
    return `${action.startTime.slice(0, 16)} → ${action.endTime.slice(0, 16)} · ${action.note}. ${t("This sends a request to the school.")}`;
  })();

  const confirmLabel = action.kind === "open" ? `${t("Open")} ${action.door?.displayName ?? ""}` : action.kind === "withdraw" ? t("Withdraw request") : t("Apply for permit");

  return (
    <Modal title={title} onClose={onClose} dismissible={!running || settled} describedBy={step === "confirm" ? "access-confirm-body" : undefined}>
      {step === "permit" && action.kind === "open" && (
        <>
          <p className="caption">{t("Select the permit to use for this gate opening.")}</p>
          <div className="rowlist">
            {openable.map((p) => (
              <button key={p.recordId} className="row row--actions" onClick={() => onStep({ action: { ...action, route: { kind: "exit_permit", permit: p } }, step: "gate" })}>
                <span className="row__main">
                  <span className="row__title">{displayReason(p)}</span>
                  <span className="row__sub">{permitWindow(p.start, p.end, now)}</span>
                </span>
              </button>
            ))}
          </div>
        </>
      )}

      {step === "gate" && action.kind === "open" && (
        <>
          <p className="overline">{action.route.kind === "day_student" ? t("Day student access") : t("Exit permit access")}</p>
          <div className="rowlist">
            {doors.map((door) => (
              <button key={door.key} className="row row--actions" onClick={() => onStep({ action: { ...action, door }, step: "confirm" })}>
                <span className="row__main">
                  <span className="row__title">{door.displayName}</span>
                </span>
              </button>
            ))}
          </div>
          <p className="caption">{t("You will confirm before the gate opens.")}</p>
        </>
      )}

      {step === "confirm" && (
        <>
          <p className="muted" id="access-confirm-body">
            {confirmBody}
          </p>
          <div className="modal__actions modal__actions--row">
            <button className="btn btn--ghost" onClick={onClose}>
              {t("Cancel")}
            </button>
            <button className={action.kind === "withdraw" ? "btn btn--danger" : "btn btn--primary"} onClick={onConfirm}>
              {confirmLabel}
            </button>
          </div>
        </>
      )}

      {step === "running" && flow.run && (
        <AccessProgress title={title} events={flow.run.events} etaLabel={etaLabel} startedAt={flow.run.startedAt} failure={flow.run.failure} onDone={onDone} />
      )}
    </Modal>
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
        <span className="caption" title={t(etaLabel)}>
          {t("Today")}
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
