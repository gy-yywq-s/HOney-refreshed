// Scroll model: FRAMED_SCROLL (§16.14.2).
// Settings (review v1.1 §17): a root of concise rows that drill into one
// detail screen each — Account, School connection (sync, saved login AND
// the imported data it produces: one subject, one screen — Gary 2026-09-02),
// How anonymity works, Appearance — so no policy paragraph sits beside a
// routine control. The hierarchy bar carries the way back.

import { useRef, useState, useEffect } from "react";
import { Link, Navigate, useNavigate, useParams } from "react-router-dom";
import { apiCache } from "../lib/useApi";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { ConfirmDialog } from "../components/Modal";
import { ThemeControls } from "../components/ThemeControls";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { ChevronRightIcon } from "../components/icons";
import { portalCredentials } from "../lib/portalCredentials";
import { timeAgo } from "../lib/format";
import { ownershipKeys } from "../lib/ownershipKeys";
import { getSurface } from "../lib/theme";
import { setLang, t, useLang } from "../lib/i18n";
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
  const textSize = useTextSize();
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(
    null,
  );
  const [confirm, setConfirm] = useState<PendingConfirm>(null);
  const [showReconnect, setShowReconnect] = useState<null | "reconnect" | "save">(null);
  // On by default; the switch reflects the wish, not whether a login is
  // stored yet (a sign-in from before the default flipped stores none).
  const [stayConnected, setStayConnected] = useState(portalCredentials.wanted());

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
              <span className="row__title">{t("Your notes & post controls")}</span>
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
              <span className="row__title">{t("Background")} · {t("Text size")} · {t("Language")}</span>
              <span className="row__sub">{t(SURFACE_LABEL[getSurface()] ?? "Stone")} · {t(TEXT_SIZE_LABEL[textSize] ?? "Default")} · {lang === "zh" ? "中文" : "English"}</span>
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
              setStayConnected(portalCredentials.wanted());
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
            <h2 className="overline">Delete account</h2>
            <p className="caption">
              Deletes your HOney account, your imported lessons and the school login saved on this
              device. Shared teacher, course, room and lesson entries stay. Published Experiences
              stay — they carry no author ID and are controlled only by the keys on your devices.
            </p>
            <button className="btn btn--danger" onClick={() => setConfirm("delete-account")}>
              {t("Delete account…")}
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
          <p className="muted">
            The plain version: HOney checks you actually have the relevant experience, published
            posts are not attached to your school account, and your device holds the control needed
            to remove your own post. The detail, honestly:
          </p>
          <ul className="privacy-list muted">
            <li>
              <strong>Published posts are stored without an author ID.</strong> The publish request
              carries no ordinary account identity, so the stored post has nothing that says who
              wrote it — HOney provides no normal author lookup, for anyone, including admins. The
              words themselves can still make you recognisable to people who know the situation.
            </li>
            <li>
              <strong>Your control is an ownership key.</strong> Each publish returns a one-time
              ownership key stored only in this browser; the server keeps only a hash. Presenting the
              key is the only way to find or remove your post.
            </li>
            <li>
              <strong>Public dates are coarse.</strong> Posts show a calendar day only; exact
              timestamps are never published.
            </li>
            <li>
              <strong>How moderation handles your text.</strong> When you run the pre-publish check,
              obvious rule-breaking wording is caught on the HOney server directly. Otherwise the
              draft text — the text only, never your identity — is sent once to an external
              moderation model (via OpenRouter) and judged transiently; HOney stores neither the
              text nor the verdict at check time. The external provider processes the text under
              its own retention policy, so don't put things in a draft you wouldn't run through a
              moderation service.
            </li>
            <li>
              <strong>Private notes stay on this device.</strong> They are scrambled at rest, so a
              casual look at browser storage won't read them — but the key sits on this device too.
              That protects against casual dumps, not against scripts running on this site or someone
              with full access to this browser. Treat them as private-on-this-device.
            </li>
          </ul>
          <section className="rowlist" aria-label="Post controls on this device">
            <h2 className="overline" id="keys" tabIndex={-1}>
              Post controls on this device
            </h2>
            <KeyManagement onFeedback={setFeedback} />
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
              <span className="row__main">
                <span className="row__sub">{t("Applies to the whole app, before the page paints.")}</span>
              </span>
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
              <span className="row__main">
                <span className="row__sub">
                  {lang === "zh"
                    ? "界面用中文；HOney、Home、Experiences、Timetable、History、Explore、Settings 这些名字保持英文。"
                    : "Sentences and actions switch; HOney, Home, Experiences, Timetable, History, Explore and Settings keep their names."}
                </span>
              </span>
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
        <ConfirmDialog
          title="Delete your HOney account?"
          body="This permanently removes your account and your imported lessons; shared teacher, course, room and lesson entries stay, and published experiences stay (they carry no author ID). The school login saved on this device is cleared. This cannot be undone."
          confirmLabel="Delete account"
          danger
          busy={busyKey === "delete-account"}
          onClose={() => setConfirm(null)}
          onConfirm={() =>
            void run("delete-account", async () => {
              await api.deleteAccount();
              portalCredentials.clear(); // the saved school login goes with the account — after the delete succeeded
              navigate("/login", { replace: true });
            })
          }
        />
      )}
      {showReconnect && (
        <ReconnectDialog
          purpose={showReconnect}
          onClose={() => setShowReconnect(null)}
          onReconnected={() => {
            setStayConnected(portalCredentials.wanted());
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

function KeyManagement({
  onFeedback,
}: {
  onFeedback: (f: { tone: "success" | "danger"; text: string } | null) => void;
}) {
  const [count, setCount] = useState(() => ownershipKeys.count());
  const fileRef = useRef<HTMLInputElement>(null);

  function exportKeys() {
    const blob = new Blob([ownershipKeys.exportJson()], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "HOney-ownership-keys.json";
    a.click();
    URL.revokeObjectURL(url);
  }

  async function importKeys(file: File) {
    try {
      const added = ownershipKeys.importJson(await file.text());
      setCount(ownershipKeys.count());
      onFeedback({
        tone: "success",
        text: added > 0 ? `Imported ${added} new ownership key${added > 1 ? "s" : ""}.` : "No new keys — everything in that file is already here.",
      });
    } catch {
      onFeedback({ tone: "danger", text: "That file is not a HOney ownership-key export." });
    }
  }

  return (
    <div className="row row--stack">
      <span className="row__main">
        <span className="row__title">Ownership keys on this device</span>
        <span className="row__sub">
          {count === 0
            ? "None yet — keys appear here when you publish an experience."
            : `${count} key${count > 1 ? "s" : ""}. Export a backup before clearing site data or switching browsers.`}
        </span>
      </span>
      <span className="row__actions">
        <button className="btn btn--ghost btn--small" onClick={exportKeys} disabled={count === 0}>
          Export
        </button>
        <button className="btn btn--ghost btn--small" onClick={() => fileRef.current?.click()}>
          Import…
        </button>
        <input
          ref={fileRef}
          type="file"
          accept="application/json,.json"
          style={{ display: "none" }}
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) void importKeys(file);
            e.target.value = "";
          }}
        />
      </span>
    </div>
  );
}
