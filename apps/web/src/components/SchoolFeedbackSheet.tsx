// The school's own feedback channel (its `student_complaints` form). This is
// NOT the Experiences space: it goes to the school, under the student's name,
// and staff read it. Both entries — the composer's small link and the
// standalone Settings row — open this one sheet.

import { useState } from "react";
import { api } from "../api/client";
import { Modal } from "./Modal";
import { useLang, useT } from "../lib/i18n";

type Bi = { en: string; zh: string };

export function SchoolFeedbackSheet({ draft = "", onClose }: { draft?: string; onClose: () => void }) {
  const lang = useLang();
  const t = useT();
  const L = (b: Bi) => (lang === "zh" ? b.zh : b.en);
  const [text, setText] = useState(draft);
  const [busy, setBusy] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function send() {
    if (text.trim().length < 4 || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await api.schoolComplaint(text.trim());
      if (res.status === "ok") {
        setSent(true);
        return;
      }
      setError(
        res.status === "refused"
          ? res.reason
          : res.status === "portal_reconnect_required"
            ? L({ en: "The school connection needs renewing.", zh: "学校连接需要重新登录。" })
            : L({ en: "The school could not be reached.", zh: "连不上学校系统。" }),
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={L({ en: "Feedback to the school", zh: "反馈给学校" })} onClose={onClose}>
      {sent ? (
        <>
          <p>{L({ en: "Sent to the school.", zh: "已发送给学校。" })}</p>
          <div className="card-actions">
            <button className="btn btn--primary" onClick={onClose}>
              {t("Done")}
            </button>
          </div>
        </>
      ) : (
        <>
          <p className="text-4">
            {L({ en: "Goes to school staff, under your name.", zh: "直接发给学校老师，带你的名字。" })}
          </p>
          <div className="field">
            <textarea
              className="input"
              rows={5}
              maxLength={2000}
              autoFocus
              placeholder={L({ en: "What should the school know?", zh: "想让学校知道什么？" })}
              value={text}
              onChange={(e) => setText(e.target.value)}
            />
          </div>
          {error && <div role="alert" className="banner banner--danger">{error}</div>}
          <div className="card-actions">
            <button className="btn btn--primary" disabled={busy || text.trim().length < 4} onClick={() => void send()}>
              {busy ? t("Saving…") : L({ en: "Send to the school", zh: "发送给学校" })}
            </button>
            <button className="btn btn--ghost" disabled={busy} onClick={onClose}>
              {L({ en: "Cancel", zh: "取消" })}
            </button>
          </div>
        </>
      )}
    </Modal>
  );
}
