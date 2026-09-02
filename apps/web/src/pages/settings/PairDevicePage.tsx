// /settings/post-controls/pair?mode=new|approve (spec §38). New device: a
// code to read out; the signed-in device types it and seals R to the new
// device's ephemeral key. Same device, another HOney: a one-time link whose
// secret lives in the fragment the server never sees.

import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { describeApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { useT } from "../../lib/i18n";
import { postControls } from "../../lib/community-v2/post-controls";
import type { UnlockedRoots } from "../../lib/community-v2/local-store";

export function PairDevicePage() {
  const { me } = useAuth();
  const [params] = useSearchParams();
  const mode = params.get("mode") === "new" ? "new" : "approve";
  if (!me) return null;
  return mode === "new" ? <NewDevice account={me.honeyId} /> : <Approve account={me.honeyId} />;
}

function NewDevice({ account }: { account: string }) {
  const t = useT();
  const navigate = useNavigate();
  const [pairing, setPairing] = useState<{ pairingId: string; expiresAt: number; privateKey: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [expired, setExpired] = useState(false);
  const timer = useRef<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    postControls
      .beginPairing()
      .then((p) => {
        if (!cancelled) setPairing(p);
      })
      .catch((err) => setError(describeApiError(err)));
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!pairing || done) return;
    const tick = async () => {
      if (Date.now() > pairing.expiresAt) {
        setExpired(true);
        return;
      }
      try {
        const roots = await postControls.completePairing(account, pairing.pairingId, pairing.privateKey);
        if (roots) {
          setDone(true);
          return;
        }
      } catch (err) {
        setError(describeApiError(err));
        return;
      }
      timer.current = window.setTimeout(() => void tick(), 2000);
    };
    void tick();
    return () => {
      if (timer.current) window.clearTimeout(timer.current);
    };
  }, [pairing, done, account]);

  if (done) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Post controls restored")}</h1>
        <section className="card card--hero">
          <p>{t("This device can now list and remove your public posts.")}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={() => navigate("/settings/post-controls", { replace: true })}>{t("Done")}</button>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="stack settings">
      <h1 className="page-title">{t("Another signed-in device")}</h1>
      <p className="caption">{t("On a phone or browser that already has your post controls, open Settings › Post controls › Another device and enter this code.")}</p>
      {error && <div role="alert" className="banner banner--danger">{error}</div>}
      {expired ? (
        <div className="banner banner--warning">
          <span>{t("This code expired.")}</span>
          <button className="btn btn--ghost btn--small" onClick={() => { setExpired(false); setPairing(null); setError(null); void postControls.beginPairing().then(setPairing).catch((e) => setError(describeApiError(e))); }}>
            {t("New code")}
          </button>
        </div>
      ) : pairing ? (
        <div className="pair-code" aria-live="polite">
          <span className="pair-code__value">{pairing.pairingId.slice(0, 4)} {pairing.pairingId.slice(4)}</span>
          <span className="caption">{t("Waiting for the other device… the code works for five minutes.")}</span>
        </div>
      ) : (
        <p className="caption">{t("Getting a code…")}</p>
      )}
    </div>
  );
}

function Approve({ account }: { account: string }) {
  const t = useT();
  const [roots, setRoots] = useState<UnlockedRoots | null | undefined>(undefined);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger" | "warning"; text: string } | null>(null);
  const [link, setLink] = useState<string | null>(null);

  useEffect(() => {
    void postControls.roots(account).then(setRoots);
  }, [account]);

  if (roots === undefined) return null;
  if (!roots) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Another device")}</h1>
        <p className="caption">{t("Post controls are not on this device, so it cannot approve another one.")}</p>
      </div>
    );
  }

  async function approve() {
    setBusy("approve");
    setFeedback(null);
    try {
      const ok = await postControls.approvePairing(roots!, code.replace(/\s+/g, "").toUpperCase());
      setFeedback(ok
        ? { tone: "success", text: t("Sent. The other device will finish in a moment.") }
        : { tone: "warning", text: t("No device is waiting with that code. Check it, or ask for a new one.") });
      if (ok) setCode("");
    } catch (err) {
      setFeedback({ tone: "danger", text: describeApiError(err) });
    } finally {
      setBusy(null);
    }
  }

  async function handoff() {
    setBusy("handoff");
    setFeedback(null);
    try {
      const url = await postControls.beginHandoff(roots!);
      setLink(url);
    } catch (err) {
      setFeedback({ tone: "danger", text: describeApiError(err) });
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="stack settings">
      <h1 className="page-title">{t("Another device")}</h1>
      {feedback && <div role={feedback.tone === "danger" ? "alert" : "status"} className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      <section className="rowlist" aria-label="Approve a new device">
        <h2 className="overline">{t("Approve a new device")}</h2>
        <p className="caption">{t("On the new device open Settings › Post controls, choose Another signed-in device, and enter its code here.")}</p>
        <div className="field">
          <label className="field__label" htmlFor="pair-code">{t("Code from the new device")}</label>
          <input id="pair-code" className="input" autoComplete="off" autoCapitalize="characters" spellCheck={false} value={code} onChange={(e) => setCode(e.target.value)} placeholder="XXXX XXXX" />
        </div>
        <div className="card-actions">
          <button className="btn btn--primary" disabled={busy !== null || code.replace(/\s+/g, "").length !== 8} onClick={() => void approve()}>
            {busy === "approve" ? t("Working…") : t("Approve")}
          </button>
        </div>
      </section>
      <section className="rowlist" aria-label="Use in another HOney">
        <h2 className="overline">{t("Use in another HOney on this device")}</h2>
        <p className="caption">{t("Safari and the installed app keep separate storage. This one-time link carries your post controls across; it works for five minutes and only once.")}</p>
        {link ? (
          <div className="field">
            <input className="input" readOnly value={link} onFocus={(e) => e.currentTarget.select()} aria-label={t("Hand-off link")} />
            <span className="caption">{t("Open this link in the other HOney on this device.")}</span>
            <div className="card-actions">
              <button className="btn btn--ghost btn--small" onClick={() => void navigator.clipboard?.writeText(link)}>{t("Copy")}</button>
              {typeof navigator.share === "function" && (
                <button className="btn btn--ghost btn--small" onClick={() => void navigator.share({ url: link })}>{t("Share…")}</button>
              )}
            </div>
          </div>
        ) : (
          <div className="card-actions">
            <button className="btn btn--ghost" disabled={busy !== null} onClick={() => void handoff()}>
              {busy === "handoff" ? t("Working…") : t("Make a one-time link")}
            </button>
          </div>
        )}
      </section>
    </div>
  );
}
