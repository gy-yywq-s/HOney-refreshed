// Scroll model: FRAMED_SCROLL (§16.14.2).
// Settings (review v1.1 §17): a root of concise rows that drill into one
// detail screen each — Account, School connection (sync, saved login AND
// the imported data it produces: one subject, one screen — Gary 2026-09-02),
// How anonymity works, Appearance — so no policy paragraph sits beside a
// routine control. The hierarchy bar carries the way back.

import { useState, useEffect } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { apiCache } from "../lib/useApi";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { ConfirmDialog, Modal } from "../components/Modal";
import { ThemeControls } from "../components/ThemeControls";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { ChevronRightIcon } from "../components/icons";
import { portalCredentials } from "../lib/portalCredentials";
import { timeAgo } from "../lib/format";
import { clearChecklist, deleteAccountAfterContent, deletePublicContent, readChecklist, type DeletionOutcome } from "../lib/community-v2/account-deletion";
import { ACCENT_OPTIONS, getAccent, getSurface } from "../lib/theme";
import { setLang, t, useLang, useT } from "../lib/i18n";
import { TEXT_SIZES, setTextSize, useTextSize } from "../lib/textSize";

type PendingConfirm = "disconnect" | "delete-data" | "delete-account" | null;
type Section = "account" | "connection" | "privacy" | "appearance";
const SECTIONS: Record<Section, string> = {
  account: "Account",
  connection: "School connection",
  privacy: "How anonymity works",
  appearance: "Appearance",
};
const TEXT_SIZE_LABEL: Record<string, string> = { small: "Small", default: "Default", large: "Large", larger: "Larger" };
const SURFACE_LABEL: Record<string, string> = { stone: "Stone", white: "White", mist: "Mist", night: "Night" };

/** One sentence for the saved-login caveat, reused wherever it is disclosed. */
export const SAVED_LOGIN_CAVEAT =
  "Your school login is encrypted and kept only on this device, and the key that unlocks it is here too — a browser is less protected than a phone’s secure storage.";

type Bi = { en: string; zh: string };
const PRIVACY_LEAD: Bi = {
  en: "The plain version: HOney checks you actually have the relevant experience, published posts are not attached to your school account, and your device holds the control needed to remove your own post. The detail, honestly:",
  zh: "简单说：HOney 会核实你确实有相关经历；发布出去的帖子不和你的学校账户挂钩；删除自己帖子所需的控制权在你的设备上。下面是坦白的细节：",
};
const PRIVACY_CLAIMS: { head: Bi; body: Bi }[] = [
  {
    head: { en: "Posts are stored by a separate service with no account database.", zh: "帖子由一个没有账户数据库的独立服务保存。" },
    body: {
      en: "The publish request carries no HOney session; what it carries is a blind token the account service signed without seeing, bound only to the class or entity you may write about. Neither service can answer who wrote a post — including for admins. The words themselves can still make you recognisable to people who know the situation.",
      zh: "发布请求不带 HOney 会话；它带的是一个账户服务在看不见内容的情况下签出的盲签令牌，只绑定你可以写的那门课或那个实体。两个服务都回答不了“谁写了这条帖子”——管理员也不行。但你写的内容本身仍可能让知情的人认出你。",
    },
  },
  {
    head: { en: "Your control is one root on your device.", zh: "你的控制权是设备上的一个根。" },
    body: {
      en: "It derives a stable posting identity per school year (so the post service can keep one post per lesson per student without knowing the student) and a separate control key for every post. Only the root can list or remove your posts; an encrypted backup restores it through a passkey, another signed-in device or 12 recovery words — the server cannot read it.",
      zh: "它推导出每学年一个的稳定发帖身份（这样帖子服务能做到每人每节课一条帖子，却不知道这个人是谁），以及每条帖子各自的控制钥匙。只有根能列出或删除你的帖子；加密备份可以通过通行密钥、另一台已登录的设备或 12 个恢复词恢复它——服务器读不了这份备份。",
    },
  },
  {
    head: { en: "Public dates are coarse.", zh: "公开的日期是粗粒度的。" },
    body: { en: "Posts show a calendar day only; exact timestamps are never published.", zh: "帖子只显示日期，精确时间从不公开。" },
  },
  {
    head: { en: "How moderation handles your text.", zh: "审核如何处理你的文字。" },
    body: {
      en: "When you run the pre-publish check, obvious rule-breaking wording is caught on the HOney server directly. Otherwise the draft text — the text only, never your identity — is sent once to an external moderation model (via OpenRouter) and judged transiently; HOney stores neither the text nor the verdict at check time. The external provider processes the text under its own retention policy, so don't put things in a draft you wouldn't run through a moderation service.",
      zh: "你运行发布前检查时，明显违规的措辞会直接在 HOney 服务器上被拦下。否则草稿文字——只有文字，从不包含你的身份——会被一次性发送给外部审核模型（经由 OpenRouter）做临时判断；检查时 HOney 既不保存文字也不保存结论。外部服务商按它自己的保留政策处理这些文字，所以不要在草稿里写你不愿交给审核服务的内容。",
    },
  },
  {
    head: { en: "Private notes stay on this device.", zh: "私人笔记只留在这台设备上。" },
    body: {
      en: "They are scrambled at rest, so a casual look at browser storage won't read them — but the key sits on this device too. That protects against casual dumps, not against scripts running on this site or someone with full access to this browser. Treat them as private-on-this-device.",
      zh: "它们在存储时是加扰的，随手翻看浏览器存储读不出来——但钥匙也在这台设备上。这能防住随意的导出，防不住在本站运行的脚本或完全掌握这个浏览器的人。把它们当作“仅在本机私密”。",
    },
  },
];

export function SettingsPage() {
  const { section: sectionParam } = useParams();
  const section = (sectionParam && sectionParam in SECTIONS ? sectionParam : null) as Section | null;
  // Deep links like /settings/privacy#keys land ON the anchor, not the page
  // top (the shell resets the scroll owner on every route change).
  useEffect(() => {
    const id = window.location.hash.slice(1);
    if (!id) return;
    requestAnimationFrame(() => {
      const el = document.getElementById(id);
      el?.scrollIntoView({ block: "start" });
      el?.focus();
    });
  }, [section]);
  const { me, refreshMe, signOut } = useAuth();
  const navigate = useNavigate();
  const lang = useLang();
  const L = (b: Bi) => (lang === "zh" ? b.zh : b.en);
  const textSize = useTextSize();
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(
    null,
  );
  const [confirm, setConfirm] = useState<PendingConfirm>(null);
  const [showReconnect, setShowReconnect] = useState<null | "reconnect" | "save">(null);
  // On by default, but the switch shows what is actually kept: a sign-in
  // from before the default flipped stored nothing, and an "on" switch over
  // an empty store left the portal asking for the login (Gary 2026-09-02).
  // Turning it on with nothing stored asks for the login once.
  const [stayConnected, setStayConnected] = useState(portalCredentials.wanted() && portalCredentials.isAuthorized());

  if (!me) return null;
  // The old Imported-data screen folded into School connection.
  if (sectionParam === "data") return <Navigate to="/settings/connection" replace />;

  async function run(key: string, fn: () => Promise<void>, successText?: string) {
    setBusyKey(key);
    setFeedback(null);
    try {
      await fn();
      if (successText) setFeedback({ tone: "success", text: successText });
    } catch (err) {
      setFeedback({ tone: "danger", text: describeApiError(err) });
    } finally {
      setBusyKey(null);
    }
  }

  const connection = me.connection;
  const connectionLine = !connection.connected
    ? t("Not connected")
    : !connection.portalTokenValid
      ? `${t("Connected")} · ${t("portal session expired")}`
      : connection.lastSyncedAt
        ? `${t("Connected")} · ${t("synced")} ${timeAgo(connection.lastSyncedAt)}`
        : `${t("Connected")} · ${t("never synced")}`;

  const feedbackEl = feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>;

  if (section === null) {
    return (
      <div className="stack settings">
        <h1 className="page-title">Settings</h1>
        {feedbackEl}

        <section className="rowlist" aria-label="Account">
          <h2 className="overline">{t("Account")}</h2>
          <Link className="row" to="/settings/account">
            <span className="row__main">
              <span className="row__title">{me.displayName}</span>
              <span className="row__sub">HOney ID {me.honeyId}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
        </section>

        <section className="rowlist" aria-label="School connection">
          <h2 className="overline">{t("School connection")}</h2>
          <Link className="row" to="/settings/connection">
            <span className="row__main">
              <span className="row__title">{connectionLine}</span>
              <span className="row__sub">{t("Sync, saved login, imported data")}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
          <div className="row">
            <span className="row__main">
              <span className="row__title">{t("Stay connected on this device")}</span>
              <span className="row__sub">{t("Reconnects automatically after routine portal time-outs.")}</span>
            </span>
            <Switch
              on={stayConnected}
              label="Stay connected on this device"
              onChange={(next) => {
                if (next) {
                  portalCredentials.setWanted(true);
                  setStayConnected(true);
                  if (!portalCredentials.isAuthorized()) setShowReconnect("save");
                } else {
                  portalCredentials.clear();
                  portalCredentials.setWanted(false);
                  setStayConnected(false);
                }
              }}
            />
          </div>
        </section>

        <section className="rowlist" aria-label="Experiences and privacy">
          <h2 className="overline">{t("Experiences & privacy")}</h2>
          <Link className="row" to="/experiences/mine">
            <span className="row__main">
              <span className="row__title">{t("Your notes & posts")}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
          <Link className="row" to="/settings/post-controls">
            <span className="row__main">
              <span className="row__title">{t("Post controls")}</span>
              <span className="row__sub">{t("Passkey, recovery words, another device")}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
          <Link className="row" to="/settings/privacy">
            <span className="row__main">
              <span className="row__title">{t("How anonymity works")}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
        </section>

        <section className="rowlist" aria-label="Appearance">
          <h2 className="overline">{t("Appearance")}</h2>
          <Link className="row" to="/settings/appearance">
            <span className="row__main">
              <span className="row__title">{t("Background")} · {t("Accent")} · {t("Text size")} · {t("Language")}</span>
              <span className="row__sub">{t(SURFACE_LABEL[getSurface()] ?? "Stone")} · {ACCENT_OPTIONS.find((o) => o.value === getAccent())?.label ?? "Harbour"} · {t(TEXT_SIZE_LABEL[textSize] ?? "Default")} · {lang === "zh" ? "中文" : "English"}</span>
            </span>
            <ChevronRightIcon size={18} />
          </Link>
        </section>

        <section className="rowlist" aria-label="About">
          <h2 className="overline">{t("About")}</h2>
          <div className="row">
            <span className="row__main">
              <span className="row__title">{t("Build")} {__BUILD__}</span>
              <span className="row__sub">{t("The app reloads itself when a newer build is live.")}</span>
            </span>
          </div>
        </section>

        {me.isAdmin && (
          <section className="rowlist" aria-label="Admin">
            <h2 className="overline">{t("Admin")}</h2>
            <Link className="row" to="/dash">
              <span className="row__main">
                <span className="row__title">{t("Open Dash")}</span>
                <span className="row__sub">{t("The operational console for admins.")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
          </section>
        )}
        {showReconnect && (
          <ReconnectDialog
            purpose={showReconnect}
            onClose={() => setShowReconnect(null)}
            onReconnected={() => {
              setStayConnected(portalCredentials.wanted() && portalCredentials.isAuthorized());
              void refreshMe();
            }}
          />
        )}
      </div>
    );
  }

  return (
    <div className="stack settings">
      <h1 className="page-title">{SECTIONS[section]}</h1>
      {feedbackEl}

      {section === "account" && (
        <>
          <section className="rowlist" aria-label="Account">
            <div className="row">
              <span className="row__main">
                <span className="row__title">{me.displayName}</span>
                <span className="row__sub">
                  HOney ID {me.honeyId} — your name inside HOney; never shown on published experiences.
                </span>
              </span>
              <button type="button" className="btn btn--danger-outline btn--small" onClick={() => void signOut()}>
                {t("Sign out")}
              </button>
            </div>
          </section>
          <section className="rowlist rowlist--danger" aria-label="Delete account">
            <h2 className="overline">Delete account and public content</h2>
            <p className="caption">
              Removes every public post your post controls can prove are yours (each with its own
              control key — no account lookup exists), then the encrypted backup, your imported
              lessons, the school login saved on this device, and the account. Shared teacher,
              course, room and lesson entries stay.
            </p>
            <button className="btn btn--danger" onClick={() => setConfirm("delete-account")}>
              {t("Delete account and public content…")}
            </button>
          </section>
        </>
      )}

      {section === "connection" && (
        <>
          <section className="rowlist" aria-label="Status">
            <div className="row">
              <span className="row__main">
                <span className="row__title">{connectionLine}</span>
                {connection.connected && !connection.portalTokenValid && (
                  <span className="row__sub">Reconnect to sync again.</span>
                )}
              </span>
            </div>
            {connection.connected && (
              <div className="row row--actions">
                <button
                  className="btn btn--primary"
                  disabled={busyKey === "sync"}
                  onClick={() =>
                    void run("sync", async () => {
                      const { result } = await api.syncSeamless();
                      if (result.status === "ok") {
                        apiCache.invalidate("timetable");
                        apiCache.invalidate("next-lesson");
                        apiCache.invalidate("history");
                        apiCache.invalidate("directory");
                        await refreshMe();
                        setFeedback({
                          tone: "success",
                          text: `Synced ${result.lessons} lessons from the school portal.`,
                        });
                      } else if (result.status === "portal_reconnect_required") {
                        setShowReconnect("reconnect");
                      } else {
                        setFeedback({ tone: "danger", text: "Could not sync right now." });
                      }
                    })
                  }
                >
                  {busyKey === "sync" ? t("Syncing with school…") : t("Sync now")}
                </button>
                {!connection.portalTokenValid && (
                  <button className="btn btn--ghost" onClick={() => setShowReconnect("reconnect")}>
                    {t("Reconnect")}
                  </button>
                )}
                <button
                  className="btn btn--ghost"
                  onClick={() => setConfirm("disconnect")}
                  disabled={busyKey === "disconnect"}
                >
                  {t("Disconnect")}
                </button>
              </div>
            )}
          </section>
          <section className="rowlist" aria-label="Saved login">
            <div className="row">
              <span className="row__main">
                <span className="row__title">{t("Stay connected on this device")}</span>
                <span className="row__sub">{t("Reconnects automatically after routine portal time-outs.")}</span>
              </span>
              <Switch
                on={stayConnected}
                label="Stay connected on this device"
                onChange={(next) => {
                  if (next) {
                    portalCredentials.setWanted(true);
                    setStayConnected(true);
                    if (!portalCredentials.isAuthorized()) setShowReconnect("save");
                  } else {
                    portalCredentials.clear();
                    portalCredentials.setWanted(false);
                    setStayConnected(false);
                  }
                }}
              />
            </div>
            <details className="disclosure">
              <summary>How the saved login works</summary>
              <p className="caption">
                Sync now signs in again with your saved school login if the portal session expired.{" "}
                {SAVED_LOGIN_CAVEAT} Turn it off any time; you will re-enter your school password
                when the portal session ends.
              </p>
            </details>
          </section>
          {/* What the connection brings in lives here too — one subject, one
              screen; the status row above already says when it last synced. */}
          <section className="rowlist" aria-label="Imported data">
            <h2 className="overline">{t("Imported data")}</h2>
            <div className="row">
              <span className="row__main">
                <span className="row__title">{t("Timetable & lesson history")}</span>
                <span className="row__sub">
                  Imported from the school portal when your account is created, and again whenever
                  you sync — Sync now, or pulling the timetable down to sync.
                </span>
              </span>
            </div>
            <details className="disclosure">
              <summary>What the import is used for</summary>
              <p className="caption">
                Your timetable and Now/Next on Home, your lesson history, and which classes count as
                yours when you share an Experience. Nothing is published from it.
              </p>
            </details>
          </section>
          <section className="rowlist rowlist--danger" aria-label="Delete imported data">
            <h2 className="overline">Delete imported data</h2>
            <p className="caption">
              Removes your imported lessons — your timetable and history. Shared teacher, course,
              room and lesson entries stay. You can import again with Sync now.
            </p>
            <button className="btn btn--danger" onClick={() => setConfirm("delete-data")}>
              {t("Delete imported data…")}
            </button>
          </section>
        </>
      )}

      {section === "privacy" && (
        <>
          {/* Bilingual (Gary 2026-09-03): the plain version, then the claims. */}
          <p className="muted">{L(PRIVACY_LEAD)}</p>
          <ul className="privacy-list muted">
            {PRIVACY_CLAIMS.map((c) => (
              <li key={c.head.en}>
                <strong>{L(c.head)}</strong> {L(c.body)}
              </li>
            ))}
          </ul>
          <section className="rowlist" aria-label="Post controls">
            <Link className="row" to="/settings/post-controls">
              <span className="row__main">
                <span className="row__title">{t("Post controls")}</span>
                <span className="row__sub">{t("Passkey, recovery words, another device")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
            <Link className="row" to="/settings/post-controls/how">
              <span className="row__main">
                <span className="row__title">{t("How post controls work")}</span>
                <span className="row__sub">{t("One root on your device · blind tokens · an encrypted backup")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
          </section>
        </>
      )}

      {section === "appearance" && (
        <>
          <section aria-label="Background">
            <ThemeControls />
          </section>
          <section className="rowlist" aria-label="Text size">
            <h2 className="overline">{t("Text size")}</h2>
            <div className="row row--stack">
              <div className="cat-chips" role="radiogroup" aria-label={t("Text size")}>
                {TEXT_SIZES.map((size) => (
                  <button
                    key={size}
                    type="button"
                    role="radio"
                    aria-checked={textSize === size}
                    aria-selected={textSize === size}
                    className="chip-tab"
                    onClick={() => setTextSize(size)}
                  >
                    {t(TEXT_SIZE_LABEL[size] ?? size)}
                  </button>
                ))}
              </div>
            </div>
          </section>
          <section className="rowlist" aria-label="Language">
            <h2 className="overline">{t("Language")}</h2>
            <div className="row row--stack">
              <div className="cat-chips" role="radiogroup" aria-label="Language">
                <button type="button" role="radio" aria-checked={lang === "en"} className="chip-tab" aria-selected={lang === "en"} onClick={() => setLang("en")}>
                  English
                </button>
                <button type="button" role="radio" aria-checked={lang === "zh"} className="chip-tab" aria-selected={lang === "zh"} onClick={() => setLang("zh")}>
                  中文
                </button>
              </div>
            </div>
          </section>
        </>
      )}

      {confirm === "disconnect" && (
        <ConfirmDialog
          title="Disconnect school account?"
          body="HOney will stop syncing until you reconnect. Imported data is kept."
          confirmLabel="Disconnect"
          busy={busyKey === "disconnect"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run(
              "disconnect",
              async () => {
                await api.disconnectSchool();
                apiCache.invalidate("");
                await refreshMe();
                setConfirm(null);
              },
              "School account disconnected.",
            )
          }
        />
      )}
      {confirm === "delete-data" && (
        <ConfirmDialog
          title="Delete imported data?"
          body="Your imported lessons — timetable and history — are removed from HOney. Shared teacher, course, room and lesson entries stay. You can import again with Sync now."
          confirmLabel="Delete imported data"
          danger
          busy={busyKey === "delete-data"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run(
              "delete-data",
              async () => {
                await api.deleteImportedData();
                await refreshMe();
                setConfirm(null);
              },
              "Imported data deleted.",
            )
          }
        />
      )}
      {confirm === "delete-account" && (
        <DeleteAccountFlow account={me.honeyId} onClose={() => setConfirm(null)} onDeleted={() => navigate("/login", { replace: true })} />
      )}
      {showReconnect && (
        <ReconnectDialog
          purpose={showReconnect}
          onClose={() => setShowReconnect(null)}
          onReconnected={() => {
            setStayConnected(portalCredentials.wanted() && portalCredentials.isAuthorized());
            void refreshMe();
          }}
        />
      )}
    </div>
  );
}

function Switch({ on, label, onChange }: { on: boolean; label: string; onChange: (next: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      className="switch"
      onClick={() => onChange(!on)}
    >
      <span className="switch__knob" />
    </button>
  );
}

/**
 * Delete account and public content (spec §40.4): revoke every post the
 * device's roots can prove, verify, then the vault and the account. When the
 * roots are not on this device nothing is deleted — the student can restore
 * them first or explicitly delete the account alone, knowing what stays.
 */
function DeleteAccountFlow({ account, onClose, onDeleted }: { account: string; onClose: () => void; onDeleted: () => void }) {
  const t = useT();
  const [step, setStep] = useState<"confirm" | "working" | "locked" | "partial" | "done">("confirm");
  const [outcome, setOutcome] = useState<DeletionOutcome | null>(null);
  const [error, setError] = useState<string | null>(null);
  const resumed = readChecklist();

  async function start(contentFirst: boolean) {
    setStep("working");
    setError(null);
    try {
      if (contentFirst) {
        const result = await deletePublicContent(account);
        setOutcome(result);
        if (result.kind === "vault_locked") {
          setStep("locked");
          return;
        }
        if (result.kind === "partial") {
          setStep("partial");
          return;
        }
      }
      await deleteAccountAfterContent(account);
      setStep("done");
      onDeleted();
    } catch (err) {
      setError(describeApiError(err));
      setStep("confirm");
    }
  }

  const body = (() => {
    if (step === "locked") {
      return (
        <>
          <p className="muted">{t("Your public posts cannot be found from the account: only your post controls can list them, and this device does not hold them.")}</p>
          <p className="muted">{t("Restore them first (passkey, another signed-in device or recovery words), then delete. Or delete the account alone — the posts stay, still unattributed, controllable only from a device that restores the backup.")}</p>
          <div className="modal__actions modal__actions--row">
            <Link className="btn btn--primary" to="/settings/post-controls" onClick={onClose}>{t("Restore post controls")}</Link>
            <button className="btn btn--danger-outline" onClick={() => void start(false)}>{t("Delete account only")}</button>
          </div>
        </>
      );
    }
    if (step === "partial" && outcome?.kind === "partial") {
      const c = outcome.checklist;
      return (
        <>
          <p className="muted">
            {t("Removed")} {c.postsRevoked} {t("of")} {c.postsFound}. {c.failedPosts.length} {t("could not be removed yet, so the account was not deleted. Your progress is kept on this device.")}
          </p>
          <div className="modal__actions modal__actions--row">
            <button className="btn btn--primary" onClick={() => void start(true)}>{t("Try the rest again")}</button>
            <button className="btn btn--danger-outline" onClick={() => void start(false)}>{t("Delete account without them")}</button>
          </div>
        </>
      );
    }
    return (
      <>
        <p className="muted" id="confirm-dialog-body">
          {t("Every public post your post controls can prove is yours is removed first, one by one, then the encrypted backup, your imported lessons and the account. The school login saved on this device is cleared. This cannot be undone.")}
        </p>
        {resumed && !outcome && <p className="caption">{t("An earlier attempt was interrupted; it continues from where it stopped.")}</p>}
        {error && <div role="alert" className="banner banner--danger">{error}</div>}
        <div className="modal__actions modal__actions--row">
          <button className="btn btn--ghost" onClick={() => { clearChecklist(); onClose(); }} disabled={step === "working"}>Cancel</button>
          <button className="btn btn--danger" onClick={() => void start(true)} disabled={step === "working"}>
            {step === "working" ? t("Working…") : t("Delete account and public content")}
          </button>
        </div>
      </>
    );
  })();

  return (
    <Modal title={t("Delete account and public content?")} onClose={onClose} describedBy="confirm-dialog-body">
      {body}
    </Modal>
  );
}
