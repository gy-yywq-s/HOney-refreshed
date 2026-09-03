// /experiences/why — the readable community ground (review v3 §9.4B), in
// both languages (Gary 2026-09-03: 其他解释页面也加上中文).
// Scroll model: DOCUMENT (one of the few long-reading pages, by design).
// This page never claims teachers can't see posts, and never promises
// absolute anonymity — copy stays inside what the implementation guarantees.

import { useLang } from "../../lib/i18n";

type Bi = { en: string; zh: string };
interface Part {
  head: Bi;
  body?: Bi;
  /** An emphasised sentence at the end of the body. */
  em?: Bi;
  list?: Bi[];
}

const TITLE: Bi = { en: "Why this space exists", zh: "为什么有这个空间" };

const PARTS: Part[] = [
  {
    head: { en: "For students, between students.", zh: "学生之间，为学生而设。" },
    body: {
      en: "School is partly understood through what people who share it tell one another. Experiences is a place for that student-to-student understanding. Teachers may be discussed here, but this is not a feedback inbox addressed to them, and no post is a final judgment of a person. Saying something to a peer, giving a teacher direct feedback, and reporting formally to the school are three different acts — this space carries the first one.",
      zh: "对学校的理解，有一部分来自同在其中的人彼此讲述。Experiences 就是承载这种学生之间理解的地方。这里可以谈到老师，但它不是写给老师的反馈信箱，任何一条帖子也不是对一个人的最终评判。对同学说一句话、直接给老师反馈、正式向学校报告，是三件不同的事——这个空间承载的是第一件。",
    },
  },
  {
    head: { en: "Why share?", zh: "为什么要分享？" },
    body: {
      en: "Something can be worth sharing because another student may find it useful, because it mattered to you and you want it represented, or both. You don’t have to dress a feeling up as advice for it to belong here.",
      zh: "一件事值得分享，可能因为别的同学会用得上，可能因为它对你很重要、你希望它被看见，也可能两者都有。不必把一种感受包装成建议，它才配出现在这里。",
    },
  },
  {
    head: { en: "Partial, but still meaningful.", zh: "片面，但仍然有意义。" },
    body: {
      en: "People are more than one experience. Experiences still matter. Read each post as one situated account, and read more than one when the context matters.",
      zh: "一个人不止一段经历，但经历仍然重要。把每条帖子当作一段有具体处境的讲述来读；当情境要紧时，多读几条。",
    },
  },
  {
    head: { en: "Negative and mixed experiences belong.", zh: "负面的、复杂的经历也属于这里。" },
    body: {
      en: "You do not need to make an experience positive, balanced, or perfectly articulated before it can matter.",
      zh: "一段经历不必先变得正面、平衡或表达完美，才有资格被重视。",
    },
    em: { en: "Negative is allowed. Cruelty is not.", zh: "可以负面，不可以刻薄。" },
  },
  {
    head: { en: "More context, fewer verdicts.", zh: "多一点情境，少一点定论。" },
    body: {
      en: "Specific context makes an experience easier to use, but it is not an entry requirement. “I cannot fully explain it, but…” is still a valid experience.",
      zh: "具体的情境让一段经历更好用，但它不是入场条件。“我说不太清楚，但是……”也是一段真实的经历。",
    },
  },
  {
    head: { en: "What verification means.", zh: "“已核实”是什么意思。" },
    body: {
      en: "HOney verifies relevant exposure where possible — that a post about a class comes from someone who took it. It does not verify every interpretation as fact. Reactions show resonance among students with relevant experience; they are not a truth vote.",
      zh: "在可能的范围内，HOney 核实相关经历——一条关于某门课的帖子确实来自上过这门课的人。它不会把每一种解读都核实为事实。反应表示有相关经历的同学是否产生共鸣，不是对真假的投票。",
    },
  },
  {
    head: { en: "Why anonymity is protected.", zh: "为什么保护匿名。" },
    body: {
      en: "HOney narrows what the public space will carry before publication, so ordinary peer speech can be strongly protected. Posts are stored by a separate service that has no account database: the request that publishes carries no HOney session, and the proof that you may share is a blind token the account service cannot recognise afterwards. Your device holds the only control over your posts. What you write may still make you recognisable to people who know the situation — anonymity is a design boundary, not magic.",
      zh: "HOney 在发布之前就限定了公开空间会承载什么，这样普通的同学间发言才能得到有力的保护。帖子由一个没有账户数据库的独立服务保存：发布请求不带 HOney 会话，而“你可以分享”的证明是一个账户服务事后认不出的盲签令牌。对你帖子的唯一控制权在你的设备上。你写的内容仍可能让知情的人认出你——匿名是一条设计边界，不是魔法。",
    },
  },
  {
    head: { en: "What this space does not carry.", zh: "这个空间不承载什么。" },
    body: {
      en: "When something reasonably calls for investigation, safeguarding, protection, or urgent action, a public peer feed is the wrong instrument. HOney will not post it — and will not secretly forward it anywhere either; it points you to the right channel and leaves the decision with you.",
      zh: "当一件事合理地需要调查、保护或紧急处理时，公开的同学信息流不是合适的工具。HOney 不会发布它——也不会偷偷转发到任何地方；它会指给你合适的渠道，并把决定权留给你。",
    },
  },
  {
    head: { en: "How to read Experiences.", zh: "怎么读 Experiences。" },
    list: [
      { en: "Read each post as one person’s situated account.", zh: "把每条帖子当作一个人在具体处境中的讲述。" },
      { en: "Compare several when the stakes matter.", zh: "事关重大时，多比较几条。" },
      { en: "Disagreement does not automatically mean fabrication.", zh: "说法不一致不等于有人编造。" },
      { en: "A reaction means “this matches / doesn’t match my experience” — nothing more.", zh: "一个反应只表示“这和我的经历相符 / 不符”，仅此而已。" },
      { en: "Entity pages give context, never a final score.", zh: "实体页提供情境，从不给出最终评分。" },
    ],
  },
];

export function ExperiencesWhyPage() {
  const lang = useLang();
  const L = (b: Bi) => (lang === "zh" ? b.zh : b.en);
  return (
    <article className="doc">
      <header>
        <h1 className="page-title">{L(TITLE)}</h1>
      </header>
      {PARTS.map((p) => (
        <section key={p.head.en}>
          <h2>{L(p.head)}</h2>
          {p.body && (
            <p>
              {L(p.body)}
              {p.em && (
                <>
                  {" "}
                  <em>{L(p.em)}</em>
                </>
              )}
            </p>
          )}
          {p.list && (
            <ul>
              {p.list.map((li) => (
                <li key={li.en}>{L(li)}</li>
              ))}
            </ul>
          )}
        </section>
      ))}
    </article>
  );
}
