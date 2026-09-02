// /settings/post-controls/replace-root (spec §40.3): not a routine action.
// A new active root for future posts; the old root stays in the encrypted
// vault so old posts remain controllable. The vault write must be read back
// and verified before this device publishes with the new root.

import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { describeApiError } from "../../api/client";
import { useAuth } from "../../auth/AuthContext";
import { ConfirmDialog } from "../../components/Modal";
import { useT } from "../../lib/i18n";
import { postControls } from "../../lib/community-v2/post-controls";
import type { UnlockedRoots } from "../../lib/community-v2/local-store";

export function RotateRootPage() {
  const { me } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const [roots, setRoots] = useState<UnlockedRoots | null | undefined>(undefined);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const account = me?.honeyId ?? "";

  useEffect(() => {
    if (account) void postControls.roots(account).then(setRoots);
  }, [account]);

  if (!me || roots === undefined) return null;

  async function rotate() {
    setBusy(true);
    setError(null);
    try {
      await postControls.rotateRoot(account, roots!);
      setDone(true);
    } catch (err) {
      setError(err instanceof Error && !("status" in err) ? err.message : describeApiError(err));
    } finally {
      setBusy(false);
      setConfirm(false);
    }
  }

  if (done) {
    return (
      <div className="stack settings">
        <h1 className="page-title">{t("Control root replaced")}</h1>
        <section className="card card--hero">
          <p>{t("New posts use the new root. Your earlier posts stay under your control through the old one, which is kept in the encrypted backup.")}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={() => navigate("/settings/post-controls", { replace: true })}>{t("Done")}</button>
          </div>
        </section>
      </div>
    );
  }

  return (
    <div className="stack settings">
      <h1 className="page-title">{t("Replace control root")}</h1>
      <p className="caption">
        {t("Use this only if you think someone else may have gained access to your post controls. It does not change or re-sign existing posts. Other devices restore the new root from the backup.")}
      </p>
      {!roots && <div className="banner banner--warning">{t("Post controls are not on this device.")}</div>}
      {error && <div role="alert" className="banner banner--danger">{error}</div>}
      <div className="card-actions">
        <button className="btn btn--danger-outline" disabled={!roots || busy} onClick={() => setConfirm(true)}>
          {t("Replace control root…")}
        </button>
      </div>
      {confirm && (
        <ConfirmDialog
          title={t("Replace the control root?")}
          body={t("Future posts will be signed by a new root. If saving the backup fails, nothing changes.")}
          confirmLabel={t("Replace")}
          danger
          busy={busy}
          onClose={() => setConfirm(false)}
          onConfirm={() => void rotate()}
        />
      )}
    </div>
  );
}
