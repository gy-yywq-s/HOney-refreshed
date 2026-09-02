// /settings/post-controls/recovery-words?mode=setup|restore (spec §37).
// Setup: show 12 words → the student saves them → two words are asked back
// → only then is the wrapper uploaded and "Recovery words ready" shown.
// Restore: 12 words in; the checksum is checked locally first; one honest
// error sentence, never "which word is wrong".

import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import type { RecoveryPhraseWrapper } from "@honey/shared/community-v2";
import { RECOVERY_WORDS, isRecoveryWord, wordsToSecret } from "@honey/shared/community-v2";
import { api, ApiError, describeApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { useT } from "../../lib/i18n";
import { Skeleton } from "../../lib/motion";
import { postControls } from "../../lib/community-v2/post-controls";
import type { UnlockedRoots } from "../../lib/community-v2/local-store";

function twoPositions(): [number, number] {
  const a = Math.floor(Math.random() * RECOVERY_WORDS);
  let b = Math.floor(Math.random() * (RECOVERY_WORDS - 1));
  if (b >= a) b += 1;
  return a < b ? [a, b] : [b, a];
}

export function RecoveryWordsPage() {
  const { me } = useAuth();
  const [params] = useSearchParams();
  const mode = params.get("mode") === "restore" ? "restore" : "setup";
  return mode === "setup" ? <Setup account={me?.honeyId ?? ""} /> : <Restore account={me?.honeyId ?? ""} />;
}

function Setup({ account }: { account: string }) {
  const t = useT();
  const navigate = useNavigate();
  const [roots, setRoots] = useState<UnlockedRoots | null>(null);
  const [prepared, setPrepared] = useState<{ words: string[]; wrapper: RecoveryPhraseWrapper } | null>(null);
  const [step, setStep] = useState<"show" | "quiz" | "done">("show");
  const [positions] = useState(twoPositions);
  const [answers, setAnswers] = useState<[string, string]>(["", ""]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!account) return;
    void postControls.roots(account).then(async (r) => {
      setRoots(r);
      if (r) setPrepared(await postControls.prepareRecoveryWords(r));
    });
  }, [account]);

  if (!account) return null;
  if (roots === null || (roots && !prepared)) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Recovery words")}</h1>
        {roots === null && prepared === null ? <Skeleton lines={4} /> : null}
        {roots === null && (
          <p className="caption">{t("Post controls are not on this device, so there is nothing to back up yet.")}</p>
        )}
      </div>
    );
  }
  const words = prepared!.words;

  async function copy() {
    try {
      await navigator.clipboard.writeText(words.join(" "));
      setCopied(true);
    } catch {
      setCopied(false);
    }
  }

  function saveFile() {
    const blob = new Blob([`HOney recovery words\n\n${words.map((w, i) => `${i + 1}. ${w}`).join("\n")}\n`], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "HOney-recovery-words.txt";
    a.click();
    URL.revokeObjectURL(url);
  }

  async function confirm() {
    const [p1, p2] = positions;
    if (answers[0].trim().toLowerCase() !== words[p1] || answers[1].trim().toLowerCase() !== words[p2]) {
      setError(t("Those are not the words at those positions. Check what you saved and try again."));
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await postControls.commitRecoveryWords(account, roots!, prepared!.wrapper);
      setStep("done");
    } catch (err) {
      setError(describeApiError(err));
    } finally {
      setBusy(false);
    }
  }

  if (step === "done") {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Recovery words ready")}</h1>
        <section className="card card--hero">
          <p>{t("These 12 words can restore control of your public posts on any device, even when no other device is signed in. Keep them somewhere only you can reach.")}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={() => navigate("/settings/post-controls", { replace: true })}>{t("Done")}</button>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="stack settings">
      <h1 className="page-title">{step === "show" ? t("Save your recovery words") : t("Check two words")}</h1>
      {step === "show" ? (
        <>
          <p className="caption">{t("These 12 words can restore control of your public posts when you do not have another signed-in device.")}</p>
          <ol className="words-grid" aria-label={t("Recovery words")}>
            {words.map((w, i) => (
              <li key={i} className="words-grid__word">
                <span className="words-grid__n">{i + 1}</span>
                <span>{w}</span>
              </li>
            ))}
          </ol>
          <div className="card-actions">
            <button className="btn btn--ghost" onClick={() => void copy()}>{copied ? t("Copied") : t("Copy")}</button>
            <button className="btn btn--ghost" onClick={saveFile}>{t("Save as file")}</button>
            <button className="btn btn--primary" onClick={() => setStep("quiz")}>{t("I've saved them")}</button>
          </div>
        </>
      ) : (
        <>
          <p className="caption">{t("Type the words at these positions, as you saved them.")}</p>
          {([0, 1] as const).map((i) => (
            <div className="field" key={i}>
              <label className="field__label" htmlFor={`word-${i}`}>{t("Word")} {positions[i] + 1}?</label>
              <input
                id={`word-${i}`}
                className="input"
                autoComplete="off"
                autoCapitalize="none"
                spellCheck={false}
                value={answers[i]}
                onChange={(e) => setAnswers((a) => (i === 0 ? [e.target.value, a[1]] : [a[0], e.target.value]))}
              />
            </div>
          ))}
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
          <div className="card-actions">
            <button className="btn btn--ghost" disabled={busy} onClick={() => { setStep("show"); setError(null); }}>{t("Show the words again")}</button>
            <button className="btn btn--primary" disabled={busy || !answers[0].trim() || !answers[1].trim()} onClick={() => void confirm()}>
              {busy ? t("Saving…") : t("Confirm")}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

function Restore({ account }: { account: string }) {
  const t = useT();
  const navigate = useNavigate();
  const [text, setText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const words = useMemo(() => text.toLowerCase().trim().split(/\s+/).filter(Boolean), [text]);
  const unknown = words.filter((w) => !isRecoveryWord(w));
  const complete = words.length === RECOVERY_WORDS && unknown.length === 0;

  async function restore() {
    setBusy(true);
    setError(null);
    try {
      if (!wordsToSecret(words)) {
        setError(t("These recovery words could not unlock this backup."));
        return;
      }
      let record;
      try {
        record = await api.vault();
      } catch (err) {
        if (err instanceof ApiError && err.status === 404) {
          setError(t("There is no backup for this account."));
          return;
        }
        throw err;
      }
      const roots = await postControls.restoreWithWords(account, record, words.join(" "));
      if (!roots) {
        setError(t("These recovery words could not unlock this backup."));
        return;
      }
      setDone(true);
    } catch (err) {
      setError(describeApiError(err));
    } finally {
      setBusy(false);
    }
  }

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
      <h1 className="page-title">{t("Enter your recovery words")}</h1>
      <div className="field">
        <label className="field__label" htmlFor="recovery-words">{t("12 words, in order")}</label>
        <textarea
          id="recovery-words"
          className="input"
          rows={4}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <span className="caption">
          {words.length}/{RECOVERY_WORDS}
          {unknown.length > 0 ? ` · ${t("not on the word list:")} ${unknown.slice(0, 3).join(", ")}` : ""}
        </span>
      </div>
      {error && <div role="alert" className="banner banner--danger">{error}</div>}
      <div className="card-actions">
        <button className="btn btn--primary" disabled={!complete || busy} onClick={() => void restore()}>
          {busy ? t("Working…") : t("Restore")}
        </button>
      </div>
    </div>
  );
}
