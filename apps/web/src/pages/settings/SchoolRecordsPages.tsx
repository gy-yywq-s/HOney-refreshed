// Scroll model: FRAMED_SCROLL. The student's own school records: campus card,
// weekend stay, disciplinary record. Read live, stored nowhere, and every
// action the school offers is offered here too (Gary 2026-09-04). Bilingual
// chrome; the school's wording is never translated — and never explained at
// length: one short line at most.

import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { CardResponse, SchoolActionResponse, SchoolReadStatus, WarningsResponse, WeekendResponse, WeekendStay } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { Skeleton } from "../../lib/motion";
import { formatShortDate, formatTime } from "../../lib/format";
import { getLang, useLang, useT } from "../../lib/i18n";
import { usePortalEntry } from "../../lib/portalEntry";
import { ConfirmDialog, Modal } from "../../components/Modal";
import { CARD_TOP_UP_AMOUNTS } from "@honey/shared/api";

type Bi = { en: string; zh: string };

function useL() {
  const lang = useLang();
  return (b: Bi) => (lang === "zh" ? b.zh : b.en);
}

/** One line for the two states that are not "here it is". */
function StateNote({ status, empty }: { status: SchoolReadStatus; empty: Bi }) {
  const L = useL();
  const t = useT();
  if (status === "portal_reconnect_required") {
    return (
      <div className="banner banner--warning">
        <span>{L({ en: "HOney needs the school connection for this.", zh: "这里需要学校连接。" })}</span>
        <Link className="btn btn--ghost btn--small" to="/settings/connection">
          {t("School connection")}
        </Link>
      </div>
    );
  }
  if (status === "unavailable") {
    return <p className="card empty">{L({ en: "The school could not be reached just now.", zh: "现在连不上学校系统。" })}</p>;
  }
  return <p className="card empty">{L(empty)}</p>;
}

function yuan(v: number): string {
  return `¥${v.toFixed(2)}`;
}

/** "Fri" / "周五" for a school day string, in the reader's language. */
function weekdayOf(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
  return date.toLocaleDateString(getLang() === "zh" ? "zh-CN" : "en-GB", { weekday: "short" });
}

/** "12 Sep" / "9月12日". */
function dayOf(iso: string): string {
  const [y, m, d] = iso.split("-").map(Number);
  const date = new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
  return date.toLocaleDateString(getLang() === "zh" ? "zh-CN" : "en-GB", { day: "numeric", month: "short" });
}

/** Settings › Campus card — balance and what it was spent on. */
export function CampusCardPage() {
  const L = useL();
  const t = useT();
  const card = useApi<CardResponse>(() => api.schoolCard(), []);
  const data = card.data;
  // Topping up happens in the school's own system (it ends in an Alipay
  // window). HOney hands the student over already signed in and takes no
  // part in the payment itself (Gary 2026-09-03).
  const portal = usePortalEntry();
  const [topUp, setTopUp] = useState(false);

  return (
    <div className="stack">
      <h1 className="page-title">{t("Campus card")}</h1>
      {card.loading && <Skeleton lines={4} />}
      {data && data.status === "ok" && data.card ? (
        <>
          <section className="card card--hero cardbalance">
            <span className="eyebrow">{L({ en: "Balance", zh: "余额" })}</span>
            <strong className="cardbalance__value">{yuan(data.card.balance)}</strong>
            <span className="text-3">
              {L({ en: "Card", zh: "卡号" })} {data.card.cardNo} ·{" "}
              {data.card.usable ? L({ en: "in use", zh: "使用中" }) : L({ en: "not in use", zh: "未启用" })}
            </span>
            <span className="caption">
              {L({ en: "General", zh: "自充值" })} {yuan(data.card.general)} · {L({ en: "Subsidy", zh: "补助" })}{" "}
              {yuan(data.card.subsidy)}
            </span>
            <div className="card-actions">
              <button className="btn btn--primary" onClick={() => setTopUp(true)}>
                {L({ en: "Top up", zh: "充值" })}
              </button>
              {!portal.needsLogin && (
                <a className="btn btn--ghost" href={portal.deepHref("/student/card")} target="_blank" rel="noopener noreferrer" onClick={portal.opened}>
                  {L({ en: "In the portal", zh: "在门户里" })}
                </a>
              )}
            </div>
          </section>

          <section className="rowlist" aria-label="Spending">
            <h2 className="overline">{L({ en: "Spending", zh: "消费记录" })}</h2>
            {data.purchases.length === 0 ? (
              <p className="caption">{L({ en: "Nothing on this card yet.", zh: "这张卡还没有消费记录。" })}</p>
            ) : (
              data.purchases.map((p) => (
                <div className="row" key={p.id}>
                  <span className="row__main">
                    <span className="row__title">{p.where}</span>
                    <span className="row__sub">
                      {formatShortDate(p.at)} · {formatTime(p.at)}
                    </span>
                  </span>
                  <span className="row__value cardrow__amount">
                    −{yuan(p.amount)}
                    <span className="caption"> {yuan(p.balanceAfter)}</span>
                  </span>
                </div>
              ))
            )}
          </section>
          {data.topUps.length > 0 && (
            <section className="rowlist" aria-label="Top-ups">
              <h2 className="overline">{L({ en: "Top-ups", zh: "充值记录" })}</h2>
              {data.topUps.map((r) => (
                <div className="row" key={r.id}>
                  <span className="row__main">
                    <span className="row__title">{yuan(r.amount)}</span>
                    <span className="row__sub">
                      {formatShortDate(r.at)} · {formatTime(r.at)}
                    </span>
                  </span>
                  <span className="row__value cardrow__amount">{r.state}</span>
                </div>
              ))}
            </section>
          )}
          <p className="text-4">{L({ en: "Read live.", zh: "实时读取。" })}</p>
        </>
      ) : data ? (
        <StateNote status={data.status} empty={{ en: "No card is registered to you.", zh: "你名下没有一卡通。" }} />
      ) : null}
      {topUp && (
        <TopUpSheet
          onClose={() => setTopUp(false)}
          onPaid={() => {
            setTopUp(false);
            card.reload();
          }}
        />
      )}
    </div>
  );
}

// The school's own recharge form offers exactly these (Gary's screenshots).
const PRESETS = CARD_TOP_UP_AMOUNTS;

/**
 * Top up: HOney asks the school to open an order and then hands the student to
 * the school's payment page (Alipay). No money moves in HOney, and an order
 * nobody pays simply stays unpaid — so this asks for an amount, not for a
 * confirmation ritual.
 */
function TopUpSheet({ onClose, onPaid }: { onClose: () => void; onPaid: () => void }) {
  const L = useL();
  const t = useT();
  const [amount, setAmount] = useState(PRESETS[0] ?? 100);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);

  async function go() {
    const value = amount;
    setBusy(true);
    setError(null);
    // The window must be opened by the tap itself, or the browser blocks it;
    // the school's answer fills it in when it arrives.
    const win = window.open("", "_blank");
    try {
      const res = await api.schoolCardTopUp(value);
      if (res.status !== "ok") {
        win?.close();
        setError(
          res.status === "refused"
            ? res.reason
            : res.status === "portal_reconnect_required"
              ? L({ en: "HOney needs the school connection for this.", zh: "这里需要学校连接。" })
              : L({ en: "The school could not be reached just now.", zh: "现在连不上学校系统。" }),
        );
        return;
      }
      if (res.payUrl) {
        if (win) win.location.href = res.payUrl;
        else window.location.href = res.payUrl;
        setSent(true);
        return;
      }
      if (res.formHtml && win) {
        // A payment form is the other shape gateways use: it has to be posted.
        win.document.write(`<!doctype html><meta charset="utf-8"><body>${res.formHtml}<script>document.forms[0].submit()<\/script></body>`);
        win.document.close();
        setSent(true);
        return;
      }
      win?.close();
      setError(
        res.message ||
          L({
            en: "The school opened the order but did not say where to pay. Open the school portal and finish it there.",
            zh: "学校已经开单，但没有给出付款地址。请到学校门户里完成付款。",
          }),
      );
    } catch {
      win?.close();
      setError(L({ en: "Could not reach HOney. Try again.", zh: "连不上 HOney，请重试。" }));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={L({ en: "Top up the card", zh: "一卡通充值" })} onClose={onClose}>
      {sent ? (
        <>
          <p>{L({ en: "The payment page is in the other tab.", zh: "付款页面在另一个标签里。" })}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={onPaid}>
              {t("Done")}
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="text-4">{L({ en: "Opens an Alipay link.", zh: "会打开支付宝链接。" })}</p>
          {/* Every amount the school offers, all of them visible. */}
          <div className="topup__amounts">
            {PRESETS.map((v) => (
              <button
                key={v}
                type="button"
                aria-pressed={amount === v}
                className={amount === v ? "btn btn--small btn--pill-ok" : "btn btn--small"}
                onClick={() => setAmount(v)}
              >
                ¥{v}
              </button>
            ))}
          </div>
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
          <div className="card-actions">
            <button className="btn btn--primary" disabled={busy} onClick={() => void go()}>
              {busy ? t("Checking…") : `${L({ en: "Continue to pay", zh: "去付款" })} ¥${amount}`}
            </button>
            <button className="btn btn--ghost" disabled={busy} onClick={onClose}>
              {L({ en: "Cancel", zh: "取消" })}
            </button>
          </div>
        </>
      )}
    </Modal>
  );
}

/** Settings › Weekend stay — apply for the open days, withdraw what is booked. */
export function WeekendStayPage() {
  const L = useL();
  const t = useT();
  const weekend = useApi<WeekendResponse>(() => api.schoolWeekend(), []);
  const portal = usePortalEntry();
  const data = weekend.data;
  const [picked, setPicked] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [note, setNote] = useState<{ tone: "success" | "danger"; text: string } | null>(null);
  const [withdrawing, setWithdrawing] = useState<WeekendStay | null>(null);

  const say = (res: SchoolActionResponse, ok: Bi): boolean => {
    if (res.status === "ok") {
      setNote({ tone: "success", text: L(ok) });
      return true;
    }
    setNote({
      tone: "danger",
      text:
        res.status === "refused"
          ? res.reason
          : res.status === "portal_reconnect_required"
            ? L({ en: "The school connection needs renewing.", zh: "学校连接需要重新登录。" })
            : L({ en: "The school could not be reached.", zh: "连不上学校系统。" }),
    });
    return false;
  };

  async function apply() {
    if (picked.length === 0 || busy) return;
    setBusy(true);
    setNote(null);
    try {
      const res = await api.schoolWeekendApply(picked);
      if (say(res, { en: "Applied.", zh: "已提交。" })) {
        setPicked([]);
        weekend.reload();
      }
    } finally {
      setBusy(false);
    }
  }

  async function withdraw(stay: WeekendStay) {
    setBusy(true);
    setNote(null);
    try {
      const res = await api.schoolWeekendWithdraw(stay.id);
      if (say(res, { en: "Withdrawn.", zh: "已撤回。" })) weekend.reload();
    } finally {
      setBusy(false);
      setWithdrawing(null);
    }
  }

  const booked = new Set((data?.stays ?? []).map((s) => s.date));
  const open = (data?.selectableDays ?? []).filter((d) => !booked.has(d));

  return (
    <div className="stack">
      <h1 className="page-title">{t("Weekend stay")}</h1>
      {weekend.loading && <Skeleton lines={4} />}
      {note && <div className={`banner banner--${note.tone}`} role="status">{note.text}</div>}
      {data && data.status === "ok" ? (
        <>
          {open.length > 0 && (
            /* Every open day, each one saying which day it is; the block is a
               tight grid, not a loose row (Gary 2026-09-04). */
            <section className="card daypick">
              <span className="eyebrow">{L({ en: "Open days", zh: "可选日期" })}</span>
              <div className="daypick__grid">
                {open.map((d) => {
                  const on = picked.includes(d);
                  return (
                    <button
                      key={d}
                      type="button"
                      aria-pressed={on}
                      className={on ? "daypick__day daypick__day--on" : "daypick__day"}
                      onClick={() => setPicked((p) => (p.includes(d) ? p.filter((x) => x !== d) : [...p, d]))}
                    >
                      <span className="daypick__weekday">{weekdayOf(d)}</span>
                      <span className="daypick__date">{dayOf(d)}</span>
                    </button>
                  );
                })}
              </div>
              <div className="card-actions">
                <button className="btn btn--primary" disabled={busy || picked.length === 0} onClick={() => void apply()}>
                  {busy ? t("Saving…") : `${L({ en: "Apply", zh: "申请" })}${picked.length > 0 ? ` · ${picked.length}` : ""}`}
                </button>
                <a className="btn btn--ghost" href={portal.deepHref("/student/weekend-plan")} target="_blank" rel="noopener noreferrer" onClick={portal.opened}>
                  {L({ en: "In the portal", zh: "在门户里" })}
                </a>
              </div>
            </section>
          )}
          <section className="rowlist" aria-label="Your weekends">
            <h2 className="overline">{L({ en: "On record", zh: "已记录" })}</h2>
            {data.stays.length === 0 ? (
              <p className="caption">{L({ en: "Nothing booked.", zh: "还没有留宿。" })}</p>
            ) : (
              data.stays.map((s) => (
                <div className="row" key={s.id}>
                  <span className="row__main">
                    <span className="row__title">{s.label || s.date}</span>
                    <span className="row__sub">
                      {s.campus}
                      {s.mentor ? ` · ${s.mentor}` : ""}
                    </span>
                  </span>
                  <span className="row__actions">
                    <button className="btn btn--ghost btn--small" disabled={busy} onClick={() => setWithdrawing(s)}>
                      {L({ en: "Withdraw", zh: "撤回" })}
                    </button>
                  </span>
                </div>
              ))
            )}
          </section>
          <p className="text-4">{L({ en: "Read live.", zh: "实时读取。" })}</p>
        </>
      ) : data ? (
        <StateNote status={data.status} empty={{ en: "Nothing booked.", zh: "还没有留宿。" }} />
      ) : null}
      {withdrawing && (
        <ConfirmDialog
          title={L({ en: "Withdraw this weekend?", zh: "撤回这次留宿？" })}
          body={withdrawing.label || withdrawing.date}
          confirmLabel={L({ en: "Withdraw", zh: "撤回" })}
          danger
          busy={busy}
          onClose={() => setWithdrawing(null)}
          onConfirm={() => void withdraw(withdrawing)}
        />
      )}
    </div>
  );
}

/** Settings › School record — the disciplinary records, in the school's words. */
export function SchoolRecordPage() {
  const L = useL();
  const t = useT();
  const warnings = useApi<WarningsResponse>(() => api.schoolWarnings(), []);
  const data = warnings.data;

  return (
    <div className="stack">
      <h1 className="page-title">{t("School record")}</h1>
      {warnings.loading && <Skeleton lines={4} />}
      {data && data.status === "ok" ? (
        data.warnings.length === 0 ? (
          <p className="card empty">{L({ en: "Nothing on record.", zh: "没有任何记录。" })}</p>
        ) : (
          <section className="rowlist" aria-label="Records">
            {data.warnings.map((w) => (
              <div className="row row--stack" key={w.id}>
                <span className="row__main">
                  <span className="row__title">{w.kind}</span>
                  <span className="row__sub">{w.rule}</span>
                  {w.reason && (
                    <span className="row__sub">
                      {L({ en: "Reason", zh: "原因" })}: {w.reason}
                    </span>
                  )}
                  <span className="caption">
                    {w.on}
                    {w.by ? ` · ${w.by}` : ""}
                  </span>
                </span>
              </div>
            ))}
          </section>
        )
      ) : data ? (
        <StateNote status={data.status} empty={{ en: "Nothing on record.", zh: "没有任何记录。" }} />
      ) : null}
      <p className="text-4">{L({ en: "Read live.", zh: "实时读取。" })}</p>
    </div>
  );
}
