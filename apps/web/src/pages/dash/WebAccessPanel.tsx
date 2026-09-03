// Dash › Web Access (spec §24): the switch that gates every physical
// request from the web, read from and written to the Access Service itself
// (Core only proxies). Default OFF; turning it on is a confirmed action.

import { useState } from "react";
import { api, ApiError } from "../../api/client";
import { ConfirmDialog } from "../../components/Modal";
import { useApi } from "../../lib/useApi";

export function WebAccessPanel() {
  const access = useApi(() => api.adminAccessStatus(), []);
  const [pending, setPending] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<{ tone: "success" | "danger"; text: string } | null>(null);
  const s = access.data?.status ?? null;
  const reachable = access.data?.reachable ?? false;

  async function apply(on: boolean) {
    setBusy(true);
    setFeedback(null);
    try {
      const r = await api.adminSetAccessEnabled(on);
      setFeedback({ tone: "success", text: r.enabled ? "Web Access is ON: students can open gates from the web now." : "Web Access is paused: nothing physical can be sent from the web." });
      setPending(null);
      access.reload();
    } catch (err) {
      setFeedback({ tone: "danger", text: err instanceof ApiError ? `Failed (${err.code}).` : "Failed. Please try again." });
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="card" aria-label="Web Access">
      <h2 className="section-title">Web Access</h2>
      {feedback && <div className={`banner banner--${feedback.tone}`}>{feedback.text}</div>}
      {access.data && !reachable && <div role="alert" className="banner banner--danger">The Access process is unreachable: the switch cannot be read or changed, and students see Web Access as unavailable.</div>}
      <div className="setting-row">
        <div className="setting-row__main">
          <span>{s ? (s.enabled ? "ON — students can open gates from the web" : "Paused — nothing physical is sent from the web") : "…"}</span>
          <span className="caption">{s ? `Access ${s.serviceVersion} · egress ${s.egress.portalOrigin} · ${s.activeOperations} in progress · ${s.unknownToday} unknown today · ${s.typicalOpen}` : ""}</span>
        </div>
        <button className={s?.enabled ? "btn btn--danger btn--small" : "btn btn--primary btn--small"} disabled={!s || busy} onClick={() => setPending(!s!.enabled)}>
          {s?.enabled ? "Pause" : "Turn on"}
        </button>
      </div>
      {pending !== null && (
        <ConfirmDialog
          title={pending ? "Turn Web Access on?" : "Pause Web Access?"}
          body={pending ? "Every signed-in student with a school connection can send physical gate and permit requests from the web immediately." : "No new physical request will be sent from the web. Requests already on the wire are not interrupted."}
          confirmLabel={pending ? "Turn on" : "Pause"}
          danger={pending}
          busy={busy}
          onClose={() => setPending(null)}
          onConfirm={() => void apply(pending)}
        />
      )}
    </section>
  );
}
