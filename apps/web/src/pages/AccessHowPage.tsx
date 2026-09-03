// /access/how — how Web Access works, in both languages, with the flow
// (Gary 2026-09-03: "通常需要几秒" becomes the relay explanation, and a page
// explains the mechanism). Scroll model: DOCUMENT. Every claim traces to
// docs/architecture/web-access.md: a signed short-lived capability, the
// portal session sealed to the Access Service, one prepare, one dispatch,
// never a retry, not-sent vs no-answer, the journal without identity, the
// measured ETA, the pause switch.

import { Flow, type FlowStep } from "../components/Flow";
import { useLang, useT } from "../lib/i18n";

type Bi = { en: string; zh: string };

export function AccessHowPage() {
  const lang = useLang();
  const t = useT();
  const L = (b: Bi) => (lang === "zh" ? b.zh : b.en);
  const step = (where: Bi, title: Bi, note?: Bi): FlowStep => {
    const s: FlowStep = { where: L(where), title: L(title) };
    if (note) s.note = L(note);
    return s;
  };
  const YOU = { en: "You", zh: "你" };
  const CORE = { en: "HOney Core · knows your account", zh: "HOney Core · 认识你的账户" };
  const ACCESS = { en: "Access service · separate process", zh: "Access 服务 · 独立进程" };
  const SCHOOL = { en: "School portal", zh: "学校门户" };

  return (
    <article className="doc">
      <header>
        <h1 className="page-title">{t("How Access works")}</h1>
      </header>

      <p className="muted">
        {L({
          en: "The plain version: when you tap a gate, your device does not talk to the school portal. It hands a short-lived, signed capability to a separate HOney process — the Access service — which makes exactly one request to the school on your behalf and reports back what the school said.",
          zh: "简单说：你点开门时，你的设备不会直接连学校门户。它把一张短时有效、带签名的凭证交给 HOney 的一个独立进程——Access 服务——由它代你向学校发送一次请求，并把学校的回复原样告诉你。",
        })}
      </p>

      <section>
        <h2>{L({ en: "Why a relay", zh: "为什么要代发" })}</h2>
        <p>
          {L({
            en: "The school portal only accepts requests from a signed-in portal session. That session stays on HOney's server, sealed so that only the Access service can open it. Your browser never holds or sends the portal token, and the school sees HOney's server, not your device.",
            zh: "学校门户只接受已登录门户会话发出的请求。这个会话留在 HOney 服务器上，并且加了封印、只有 Access 服务能解开。你的浏览器从不持有或发送门户令牌；学校看到的是 HOney 的服务器，不是你的设备。",
          })}
        </p>
      </section>

      <section>
        <h2>{L({ en: "Opening a gate", zh: "开门的过程" })}</h2>
        <Flow
          label={L({ en: "Opening a gate", zh: "开门的过程" })}
          steps={[
            step(YOU, { en: "Choose a gate and confirm", zh: "选择闸门并确认" }),
            step(CORE, { en: "Signs a capability that lasts a few minutes", zh: "签发一张几分钟内有效的凭证" }, { en: "It seals your portal session so that only the Access service can read it. The capability names a pseudonym, never your account.", zh: "它把你的门户会话封印，只有 Access 服务能解开；凭证里是一个化名，不是你的账户。" }),
            step(ACCESS, { en: "Prepares: reads the door and your permit fresh", zh: "准备：重新读取闸门和你的申请" }, { en: "One operation at a time per student, and a one-time confirmation secret that lasts 60 seconds.", zh: "每人同一时间只有一个操作；一次性的确认密钥，60 秒内有效。" }),
            step(ACCESS, { en: "Sends exactly one request to the school", zh: "向学校发送且只发送一次请求" }, { en: "Never retried. This process can reach only the school portal's address — nothing else on the internet.", zh: "从不重试。这个进程只能连到学校门户的地址，连不上互联网上的任何其他地方。" }),
            step(SCHOOL, { en: "Answers: confirmed or declined", zh: "回复：已确认或已拒绝" }, { en: "When the school gives a reason, you see its own words.", zh: "学校给出理由时，你看到的是它的原话。" }),
          ]}
        />
      </section>

      <section>
        <h2>{L({ en: "What the progress sheet tells you", zh: "进度弹层里的状态" })}</h2>
        <p>
          {L({
            en: "Accepted → sending → waiting for the school → confirmed, declined, not sent, or no answer. “Not sent” means the request provably never left HOney. “No answer” means it may have reached the school — check the gate before trying again.",
            zh: "已受理 → 发送中 → 等待学校 → 已确认 / 已拒绝 / 未发送 / 无回应。“未发送”表示请求确定没有离开 HOney；“无回应”表示它可能已到达学校——再试之前先看看闸门。",
          })}
        </p>
      </section>

      <section>
        <h2>{L({ en: "What the Access service keeps", zh: "Access 服务保存什么" })}</h2>
        <p>
          {L({
            en: "A journal of each operation: when it was prepared, sent and answered, and the outcome. It stores a hash of your pseudonym — never your name, account, password or portal token — and it has no database of students.",
            zh: "每个操作的日志：准备、发送、回复的时间和结果。它保存的是化名的哈希——从不保存你的姓名、账户、密码或门户令牌——也没有学生数据库。",
          })}
        </p>
      </section>

      <section>
        <h2>{L({ en: "Timing", zh: "关于时长" })}</h2>
        <p>
          {L({
            en: "The “usually … seconds” estimate is measured from recent operations of the same kind — from the median to the 90th percentile of the last 100. With fewer than five samples it only says “a few seconds”.",
            zh: "“通常需要 … 秒”来自最近同类操作的实测：最近 100 次的中位数到第 90 百分位。样本少于 5 次时只说“几秒”。",
          })}
        </p>
      </section>

      <section>
        <h2>{L({ en: "Limits", zh: "限制" })}</h2>
        <ul>
          <li>{L({ en: "HOney can pause Web Access. A paused request is journaled and nothing is sent; a request already on the wire is not interrupted.", zh: "HOney 可以暂停网页门禁。被暂停的请求会被记录，并且什么也不会发送；已经发出的请求不会被打断。" })}</li>
          <li>{L({ en: "Physical authority always comes from a fresh check: a stale permit list cannot open a gate until it is refreshed.", zh: "开门的依据永远来自最新读取：过期的出门申请列表在刷新之前不能用来开门。" })}</li>
        </ul>
      </section>
    </article>
  );
}
