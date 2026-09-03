// /settings/post-controls/how — how post controls work, in both languages,
// with flow diagrams (Gary 2026-09-03). Scroll model: DOCUMENT.
// Every claim here is one the protocol provides (docs/architecture/
// anonymous-control-v2.md): one client-made root, a key per post, blind
// eligibility, an identity-free Community, an encrypted vault the server
// cannot open, three ways to restore, retained legacy roots — and the honest
// limits. Nothing about the network being anonymous, nothing about magic.

import { Link } from "react-router-dom";
import { Flow, type FlowStep } from "../../components/Flow";
import { ChevronRightIcon } from "../../components/icons";
import { useLang, useT } from "../../lib/i18n";

type Bi = { en: string; zh: string };
const pick = (lang: "en" | "zh", b: Bi) => (lang === "zh" ? b.zh : b.en);

const WHERE = {
  you: { en: "You", zh: "你" },
  device: { en: "This device", zh: "这台设备" },
  core: { en: "HOney Core · knows your account", zh: "HOney Core · 认识你的账户" },
  coreShort: { en: "HOney Core", zh: "HOney Core" },
  community: { en: "HOney Community · no accounts", zh: "HOney Community · 没有账户" },
};

export function PostControlsHowPage() {
  const lang = useLang();
  const t = useT();
  const L = (b: Bi) => pick(lang, b);
  const step = (where: Bi, title: Bi, note?: Bi, options?: Bi[]): FlowStep => {
    const s: FlowStep = { where: L(where), title: L(title) };
    if (note) s.note = L(note);
    if (options) s.options = options.map(L);
    return s;
  };

  return (
    <article className="doc">
      <header>
        <h1 className="page-title">{t("How post controls work")}</h1>
      </header>

      <p className="muted">
        {L({
          en: "The plain version: one root, created on your device, controls every public post you make. HOney's server never sees the root — it keeps only an encrypted backup it cannot open.",
          zh: "简单说：你的设备生成一个根密钥，它控制你发布的每一条公开帖子。HOney 服务器从不接触这个根，只保存一份它自己打不开的加密备份。",
        })}
      </p>

      <section>
        <h2>{L({ en: "One root, a key per post", zh: "一个根，每条帖子一把钥匙" })}</h2>
        <p>
          {L({
            en: "Your device draws 32 random bytes — the root. From it HOney derives a posting identity for each school year, and a separate control key for every post. Whoever holds the root controls every post; one post's key says nothing about the others.",
            zh: "你的设备随机生成 32 字节作为根。HOney 由它推导出每个学年一个的发帖身份，以及每条帖子各自独立的控制钥匙。持有根就掌握全部帖子；单条帖子的钥匙推不出其他任何钥匙。",
          })}
        </p>
        <Flow
          label={L({ en: "Key hierarchy", zh: "密钥层级" })}
          steps={[
            step(WHERE.device, { en: "Control root", zh: "控制根" }, { en: "32 random bytes, generated here. It never leaves the device in the clear.", zh: "在本机随机生成的 32 字节，从不以明文离开设备。" }),
            step(WHERE.device, { en: "Posting identity — one per school year", zh: "发帖身份——每学年一个" }, { en: "Lets Community keep one post per lesson per contributor without knowing who the contributor is.", zh: "让 Community 能做到每人每节课一条帖子，却不知道这个人是谁。" }),
            step(WHERE.device, { en: "Control key — one per post", zh: "控制钥匙——每条帖子一把" }, { en: "Re-derived from the root and the post's own nonce; only it can list or remove that post.", zh: "由根加上该帖子自己的随机数推导；只有它能列出或删除这条帖子。" }),
          ]}
        />
      </section>

      <section>
        <h2>{L({ en: "Publishing without your account", zh: "发布时不带账户" })}</h2>
        <p>
          {L({
            en: "Before you share, HOney Core checks that you actually had that class or place and blind-signs a token: it signs something it cannot read, so it can never tell afterwards which post came from which check. The post itself goes to a separate Community process that has no account database. The request carries no session, no cookie and no account id.",
            zh: "分享之前，HOney Core 先核实你确实上过那门课或到过那个地方，然后对一个令牌做盲签名：它签的是自己看不见的内容，事后无法把某条帖子和某次核实对上。帖子本身发给一个独立的 Community 进程，那里没有账户数据库；这个请求不带会话、不带 Cookie、不带账户 ID。",
          })}
        </p>
        <Flow
          label={L({ en: "Publishing a post", zh: "发布一条帖子" })}
          steps={[
            step(WHERE.you, { en: "Pick the lesson, write the post", zh: "选课，写下经历" }),
            step(WHERE.core, { en: "Checks you were there and blind-signs a token", zh: "核实你在场，并盲签一个令牌" }, { en: "It learns what you asked for — which it already knew — never the token it will later be shown.", zh: "它只知道你申请了什么（本来就知道），却认不出之后出现的令牌。" }),
            step(WHERE.device, { en: "Unblinds the token, signs the post with the posting key", zh: "解盲令牌，用发帖钥匙给帖子签名" }),
            step(WHERE.community, { en: "Verifies the token and the signature, stores the post", zh: "验证令牌和签名，保存帖子" }, { en: "No session, no cookie, no account id arrives here; a token is accepted once.", zh: "这里收不到会话、Cookie 或账户 ID；令牌只能用一次。" }),
          ]}
        />
      </section>

      <section>
        <h2>{L({ en: "Backup and restore", zh: "备份与恢复" })}</h2>
        <p>
          {L({
            en: "The root is encrypted on your device and only the ciphertext — the Control Vault — is kept on HOney Core. Three things can open it: a passkey (Face ID, Touch ID or your device passcode), another device that is already signed in, or your 12 recovery words. Core stores no root, no passkey secret and no words. A device shows “restored” only after it has read the backup back and decrypted it.",
            zh: "根在你的设备上加密，HOney Core 只保存密文（Control Vault）。能打开它的有三样：通行密钥（Face ID、Touch ID 或设备密码）、另一台已登录的设备、或你的 12 个恢复词。Core 不保存根、不保存通行密钥的秘密、也不保存恢复词。设备只有在把备份读回并成功解密之后才会显示“已恢复”。",
          })}
        </p>
        <Flow
          label={L({ en: "Restoring on a new device", zh: "在新设备上恢复" })}
          steps={[
            step(WHERE.coreShort, { en: "Encrypted backup — ciphertext only", zh: "加密备份——只有密文" }),
            step(WHERE.you, { en: "Choose one way to open it", zh: "选一种方式打开" }, undefined, [
              { en: "Passkey", zh: "通行密钥" },
              { en: "Another signed-in device", zh: "另一台已登录设备" },
              { en: "12 recovery words", zh: "12 个恢复词" },
            ]),
            step(WHERE.device, { en: "Root restored here", zh: "根回到这台设备" }, { en: "Counted as done only after the backup was read back and decrypted.", zh: "读回备份并解密成功后才算完成。" }),
          ]}
        />
      </section>

      <section>
        <h2>{L({ en: "What each side can see", zh: "各方看得到什么" })}</h2>
        <div className="doc__scroll">
          <table className="who">
            <tbody>
              <tr>
                <th>{L(WHERE.device)}</th>
                <td>{L({ en: "The root, every key, and the list of your posts.", zh: "根、所有钥匙，以及你的帖子列表。" })}</td>
              </tr>
              <tr>
                <th>{L({ en: "HOney Core (your account)", zh: "HOney Core（你的账户）" })}</th>
                <td>{L({ en: "Who you are and what you were eligible to write about — never the token, the root or a post.", zh: "你是谁、你有资格写什么——从不接触令牌、根或帖子。" })}</td>
              </tr>
              <tr>
                <th>{L({ en: "HOney Community (posts)", zh: "HOney Community（帖子）" })}</th>
                <td>{L({ en: "Posts, signatures and the token's public scope. It has no account database.", zh: "帖子、签名和令牌的公开范围。这里没有账户数据库。" })}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2>{L({ en: "Replacing or erasing", zh: "更换或清除" })}</h2>
        <ul>
          <li>
            {L({
              en: "Replace the root only if you think this device was compromised. The old root is kept alongside the new one, so the posts it made stay under your control.",
              zh: "只有在怀疑这台设备被入侵时才更换根。旧根会和新根一起保留，它发过的帖子仍归你控制。",
            })}
          </li>
          <li>
            {L({
              en: "Erasing removes the root from this device; the encrypted backup stays. HOney will not create a second root while a backup exists — a new root could not remove the posts the old one controls.",
              zh: "清除只是把根从这台设备移除，加密备份仍在。只要备份存在，HOney 不会创建第二个根——新根删不掉旧根控制的帖子。",
            })}
          </li>
        </ul>
      </section>

      <section>
        <h2>{L({ en: "Honest limits", zh: "坦白的限制" })}</h2>
        <ul>
          <li>{L({ en: "This is application-level anonymity: the network still sees your IP address and timing.", zh: "这是应用层面的匿名：网络仍能看到你的 IP 地址和时间。" })}</li>
          <li>{L({ en: "Lose every way to restore and you lose control of your posts.", zh: "所有恢复方式都丢了，就失去对帖子的控制。" })}</li>
          <li>{L({ en: "What you write can still make you recognisable to people who know the situation.", zh: "你写的内容仍可能让知情的人认出你。" })}</li>
        </ul>
      </section>

      <footer className="doc__footer">
        <section className="rowlist" aria-label="Post controls">
          <Link className="row" to="/settings/post-controls">
            <span className="row__main">
              <span className="row__title">{t("Post controls")}</span>
              <span className="row__sub">{t("Passkey, recovery words, another device")}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
        </section>
      </footer>
    </article>
  );
}
