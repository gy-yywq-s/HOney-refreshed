// Scroll model: FRAMED_SCROLL (§16.14.2).
// /settings/post-controls — Anonymous Control v2 on this device (spec §35–§40):
// one client-generated root controls every public post; this screen shows
// whether the root is here, how it can be restored (passkey · another
// device · recovery words, in that order) and the advanced actions. Copy
// states only what the protocol provides; success appears only after a
// durable write was read back.

import { useCallback, useEffect, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { ConfirmDialog } from "../../components/Modal";
import { ChevronRightIcon } from "../../components/icons";
import { useT } from "../../lib/i18n";
import { Skeleton } from "../../lib/motion";
import { postControls } from "../../lib/community-v2/post-controls";
import { passkeysAvailable } from "../../lib/community-v2/passkey-prf";
import type { VaultStatus } from "../../lib/community-v2/vault-client";
import { describeApiError } from "../../api/client";

type Feedback = { tone: "success" | "danger" | "warning"; text: string } | null;

export function PostControlsPage() {
  const { me } = useAuth();
  const location = useLocation();
  const t = useT();
  const [status, setStatus] = useState<VaultStatus | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<Feedback>(null);
  const [confirmErase, setConfirmErase] = useState(false);

  const account = me?.honeyId ?? "";

  const reload = useCallback(async () => {
    if (!account) return;
    setError(null);
    try {
      setStatus(await postControls.status(account));
    } catch (err) {
      setError(describeApiError(err));
    }
  }, [account]);

  useEffect(() => {
    void reload();
  }, [reload]);

  // A hand-off link from another HOney on this device (#handoff=…).
  useEffect(() => {
    if (!account || !location.hash.startsWith("#handoff=")) return;
    const fragment = location.hash;
    history.replaceState(null, "", location.pathname);
    setBusy("handoff");
    void postControls
      .completeHandoff(account, fragment)
      .then((roots) => {
        setFeedback(roots ? { tone: "success", text: t("Post controls restored on this device.") } : { tone: "warning", text: t("That link has already been used or has expired.") });
        return reload();
      })
      .catch((err) => setFeedback({ tone: "danger", text: describeApiError(err) }))
      .finally(() => setBusy(null));
  }, [account, location.hash, location.pathname, reload, t]);

  if (!me) return null;

  async function run(key: string, fn: () => Promise<Feedback | void>) {
    setBusy(key);
    setFeedback(null);
    try {
      const fb = await fn();
      if (fb) setFeedback(fb);
      await reload();
    } catch (err) {
      setFeedback({ tone: "danger", text: err instanceof Error && !("status" in err) ? err.message : describeApiError(err) });
    } finally {
      setBusy(null);
    }
  }

  const feedbackEl = feedback && (
    <div role={feedback.tone === "danger" ? "alert" : "status"} className={`banner banner--${feedback.tone}`}>
      {feedback.text}
    </div>
  );

  if (error) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Post controls")}</h1>
        <div role="alert" className="banner banner--danger">
          <span>{error}</span>
          <button className="btn btn--ghost btn--small" onClick={() => void reload()}>{t("Try again")}</button>
        </div>
      </div>
    );
  }

  if (!status) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Post controls")}</h1>
        <Skeleton lines={4} />
      </div>
    );
  }

  const passkeyWrappers = status.kind === "ready" ? status.wrappers.filter((w) => w.type === "passkey_prf") : [];
  const hasWords = status.kind === "ready" && status.wrappers.some((w) => w.type === "recovery_phrase");
  const restoreWrappers = status.kind === "restore_needed" ? status.record.wrappers : [];

  return (
    <div className="stack settings">
      <h1 className="page-title">{t("Post controls")}</h1>
      {feedbackEl}

      {status.kind === "unsupported" && (
        <div className="banner banner--warning">{t("This browser cannot keep post controls. Use Safari, Chrome or the installed HOney app.")}</div>
      )}

      {status.kind === "none" && (
        <section className="rowlist" aria-label="Set up">
          <p className="caption">
            {t("Your public posts are controlled by one root created on your device. HOney's server never sees it; it only stores an encrypted backup you can restore with a passkey, another signed-in device or 12 recovery words.")}
          </p>
          <div className="row row--actions">
            <button className="btn btn--primary" disabled={busy !== null} onClick={() => void run("create", async () => { await postControls.create(account); return { tone: "success", text: t("Post controls created on this device. Add a way to restore them next.") }; })}>
              {busy === "create" ? t("Working…") : t("Set up post controls")}
            </button>
          </div>
        </section>
      )}

      {status.kind === "restore_needed" && (
        <>
          <section className="rowlist" aria-label="Restore">
            <h2 className="overline">{t("Restore on this device")}</h2>
            <p className="caption">{t("Your post controls are backed up, but this device does not have them yet. Pick the way that suits you.")}</p>
            {restoreWrappers.some((w) => w.type === "passkey_prf") && passkeysAvailable() && (
              <div className="row">
                <span className="row__main">
                  <span className="row__title">{t("Use your passkey to restore post controls")}</span>
                  <span className="row__sub">{t("Face ID, Touch ID or your device passcode.")}</span>
                </span>
                <button className="btn btn--primary btn--small" disabled={busy !== null} onClick={() => void run("passkey-restore", async () => {
                  const roots = await postControls.restoreWithPasskey(account, status.record);
                  return roots ? { tone: "success", text: t("Post controls restored on this device.") } : { tone: "warning", text: t("That passkey could not restore them here. Try another way below.") };
                })}>
                  {busy === "passkey-restore" ? t("Working…") : t("Use passkey")}
                </button>
              </div>
            )}
            <Link className="row" to="/settings/post-controls/pair?mode=new">
              <span className="row__main">
                <span className="row__title">{t("Another signed-in device")}</span>
                <span className="row__sub">{t("Approve from a phone or browser that already has them.")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
            {restoreWrappers.some((w) => w.type === "recovery_phrase") && (
              <Link className="row" to="/settings/post-controls/recovery-words?mode=restore">
                <span className="row__main">
                  <span className="row__title">{t("12 recovery words")}</span>
                </span>
                <ChevronRightIcon size={18} />
              </Link>
            )}
          </section>
          <section className="rowlist" aria-label="Start over">
            <p className="caption">{t("HOney will not create a second root while a backup exists: a new root could not remove the posts the old one controls.")}</p>
          </section>
        </>
      )}

      {(status.kind === "local_only" || status.kind === "ready") && (
        <>
          <section className="rowlist" aria-label="Status">
            <div className="row">
              <span className="row__main">
                <span className="row__title">{status.kind === "ready" ? t("Post controls are on this device and backed up.") : t("Post controls are on this device only.")}</span>
                <span className="row__sub">
                  {status.kind === "ready"
                    ? t("The backup is encrypted; the server cannot read it.")
                    : t("Add a way to restore them before you clear this browser or change phones.")}
                </span>
              </span>
            </div>
          </section>

          <section className="rowlist" aria-label="Ways to restore">
            <h2 className="overline">{t("Ways to restore")}</h2>
            {passkeysAvailable() && (
              <div className="row">
                <span className="row__main">
                  <span className="row__title">{t("Passkey")}</span>
                  <span className="row__sub">
                    {passkeyWrappers.length === 0
                      ? t("Face ID, Touch ID or your device passcode, where the browser supports it.")
                      : passkeyWrappers.map((w) => (w.type === "passkey_prf" ? w.label ?? t("Passkey") : "")).join(" · ")}
                  </span>
                </span>
                <button className="btn btn--ghost btn--small" disabled={busy !== null} onClick={() => void run("passkey", async () => {
                  const roots = status.roots;
                  const result = await postControls.addPasskey(account, roots, me.displayName);
                  if (result.ok) return { tone: "success", text: t("Passkey ready. It was checked with a fresh sign-in before being saved.") };
                  if (result.reason === "unsupported") return { tone: "warning", text: t("This browser or passkey cannot be used for post controls. Recovery words or another device still work.") };
                  if (result.reason === "cancelled") return { tone: "warning", text: t("Cancelled. Nothing was saved.") };
                  return { tone: "danger", text: t("The passkey could not be verified, so it was not saved.") };
                })}>
                  {busy === "passkey" ? t("Working…") : passkeyWrappers.length === 0 ? t("Add") : t("Add another")}
                </button>
              </div>
            )}
            <Link className="row" to="/settings/post-controls/recovery-words?mode=setup">
              <span className="row__main">
                <span className="row__title">{t("Recovery words")}</span>
                <span className="row__sub">{hasWords ? t("Ready · 12 words") : t("12 words that restore control when no other device is signed in.")}</span>
              </span>
              <span className="row__act">{hasWords ? t("Replace") : t("Set up")} <ChevronRightIcon size={16} /></span>
            </Link>
            <Link className="row" to="/settings/post-controls/pair?mode=approve">
              <span className="row__main">
                <span className="row__title">{t("Another device")}</span>
                <span className="row__sub">{t("Approve a new phone or browser, or use in another HOney on this device.")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
          </section>

          <section className="rowlist" aria-label="Advanced">
            <h2 className="overline">{t("Advanced")}</h2>
            <Link className="row" to="/settings/post-controls/replace-root">
              <span className="row__main">
                <span className="row__title">{t("Replace control root")}</span>
                <span className="row__sub">{t("Only if you think this device was compromised. Old posts stay under your control.")}</span>
              </span>
              <ChevronRightIcon size={18} />
            </Link>
            <div className="row">
              <span className="row__main">
                <span className="row__title">{t("Erase local post controls")}</span>
                <span className="row__sub">{t("Removes the root from this device. The encrypted backup stays.")}</span>
              </span>
              <button className="btn btn--danger-outline btn--small" disabled={busy !== null} onClick={() => setConfirmErase(true)}>
                {t("Erase…")}
              </button>
            </div>
          </section>
        </>
      )}

      {confirmErase && (
        <ConfirmDialog
          title={t("Erase post controls from this device?")}
          body={status.kind === "local_only"
            ? t("There is no backup yet. After this, no device can remove the posts this root controls.")
            : t("This device will need a passkey, another device or the recovery words to control your posts again.")}
          confirmLabel={t("Erase")}
          danger
          busy={busy === "erase"}
          onClose={() => setConfirmErase(false)}
          onConfirm={() => {
            setConfirmErase(false);
            void run("erase", async () => {
              await postControls.eraseLocal(account);
              return { tone: "success", text: t("Post controls erased from this device.") };
            });
          }}
        />
      )}
    </div>
  );
}
