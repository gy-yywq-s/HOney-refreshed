// Scroll model: FRAMED_SCROLL. The student's own records at the school
// (Gary 2026-09-03): the campus card, weekend stay-overs, and the school's
// disciplinary record. HOney stores NONE of it — every visit reads it live
// with the student's own portal session and shows the school's own words.
// Bilingual chrome; the school's wording is never translated.

import { Link } from "react-router-dom";
import { api } from "../../api/client";
import type { CardResponse, SchoolReadStatus, WarningsResponse, WeekendResponse } from "../../api/types";
import { useApi } from "../../lib/useApi";
import { Skeleton } from "../../lib/motion";
import { formatShortDate, formatTime } from "../../lib/format";
import { useLang, useT } from "../../lib/i18n";

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

/** Settings › Campus card — balance and what it was spent on. */
export function CampusCardPage() {
  const L = useL();
  const t = useT();
  const card = useApi<CardResponse>(() => api.schoolCard(), []);
  const data = card.data;

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
          <p className="text-4">
            {L({
              en: "Read from the school's card system when you open this page. HOney keeps no copy. Topping up is done in the school portal.",
              zh: "打开本页时才从学校的一卡通系统读取，HOney 不留副本。充值请在学校门户里进行。",
            })}
          </p>
        </>
      ) : data ? (
        <StateNote status={data.status} empty={{ en: "No card is registered to you.", zh: "你名下没有一卡通。" }} />
      ) : null}
    </div>
  );
}

/** Settings › Weekend stay — the records the school holds and the open days. */
export function WeekendStayPage() {
  const L = useL();
  const t = useT();
  const weekend = useApi<WeekendResponse>(() => api.schoolWeekend(), []);
  const data = weekend.data;

  return (
    <div className="stack">
      <h1 className="page-title">{t("Weekend stay")}</h1>
      {weekend.loading && <Skeleton lines={4} />}
      {data && data.status === "ok" ? (
        <>
          {data.selectableDays.length > 0 && (
            <section className="card">
              <span className="eyebrow">{L({ en: "Open for booking", zh: "可选日期" })}</span>
              <p className="text-3" style={{ marginBottom: 0 }}>
                {data.selectableDays.join(" · ")}
              </p>
              <p className="caption" style={{ marginBottom: 0 }}>
                {L({
                  en: "Booking a weekend is done in the school portal — HOney only shows what the school has on record.",
                  zh: "申请留宿仍在学校门户里操作——HOney 只显示学校记录在案的内容。",
                })}
              </p>
            </section>
          )}
          <section className="rowlist" aria-label="Your weekends">
            <h2 className="overline">{L({ en: "On record", zh: "已记录" })}</h2>
            {data.stays.length === 0 ? (
              <p className="caption">{L({ en: "No weekend stays on record.", zh: "没有留宿记录。" })}</p>
            ) : (
              data.stays.map((s) => (
                <div className="row" key={s.id}>
                  <span className="row__main">
                    <span className="row__title">{s.label || s.date}</span>
                    <span className="row__sub">
                      {s.campus}
                      {s.mentor ? ` · ${L({ en: "mentor", zh: "导师" })} ${s.mentor}` : ""}
                    </span>
                  </span>
                </div>
              ))
            )}
          </section>
        </>
      ) : data ? (
        <StateNote status={data.status} empty={{ en: "No weekend stays on record.", zh: "没有留宿记录。" }} />
      ) : null}
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
      <p className="muted">
        {L({
          en: "What the school has recorded about you. It is read live and kept nowhere in HOney — no one else can see it here, and nothing about it is ever attached to an Experience.",
          zh: "学校记录在案的、关于你的内容。每次打开都是实时读取，HOney 不做任何保存——别人在这里看不到，也永远不会和任何一条经历关联。",
        })}
      </p>
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
    </div>
  );
}
