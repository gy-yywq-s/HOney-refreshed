// One school notice, read in a sheet (Gary 2026-09-03: 通知用 sheet 不要单独
// 界面 但是可以进入单独界面来看, sheet 往上拉即可放大). The sheet opens at
// reading height, a pull up takes it full-height, and "Open as a page" still
// leads to /notices/:id. The school's words are shown exactly as written;
// where the school wrote a file link it becomes a real link to the portal.

import { useEffect, type ReactNode } from "react";
import { Link } from "react-router-dom";
import type { SchoolNotice } from "../api/types";
import { Modal } from "./Modal";
import { formatRelativeDay, formatTime } from "../lib/format";
import { markNoticeRead } from "../lib/noticesRead";
import { useT } from "../lib/i18n";

// The school writes its attachments into the text as `[name.pdf](</path>)`
// (live capture 2026-09-03).
const FILE_LINK = /\[([^\]]+)\]\(\s*<?([^)>]+?)>?\s*\)/g;

function noticeHref(target: string, origin: string): string | null {
  const path = target.trim();
  if (/^https?:\/\//i.test(path)) return encodeURI(path);
  if (path.startsWith("/")) return origin ? `${origin.replace(/\/$/, "")}${encodeURI(path)}` : null;
  return null;
}

export function renderNoticeBody(body: string, origin: string): ReactNode[] {
  const out: ReactNode[] = [];
  let last = 0;
  for (const m of body.matchAll(FILE_LINK)) {
    const at = m.index ?? 0;
    if (at > last) out.push(body.slice(last, at));
    const href = noticeHref(m[2] ?? "", origin);
    out.push(
      href ? (
        <a key={`${at}`} className="notice-doc__file" href={href} target="_blank" rel="noopener noreferrer">
          {m[1]}
        </a>
      ) : (
        m[0]
      ),
    );
    last = at + m[0].length;
  }
  out.push(body.slice(last));
  return out;
}

export function NoticeSheet({
  notice,
  portalOrigin,
  onClose,
}: {
  notice: SchoolNotice;
  portalOrigin: string;
  onClose: () => void;
}) {
  const t = useT();

  // Opening a notice reads it — on this device only.
  useEffect(() => {
    markNoticeRead(notice.id);
  }, [notice.id]);

  return (
    <Modal title={notice.title} onClose={onClose} expandable>
      <p className="caption notice-doc__meta">
        {formatRelativeDay(notice.postedAt)} · {formatTime(notice.postedAt)}
        {notice.updatedAt > notice.postedAt ? ` · ${t("Edited")} ${formatRelativeDay(notice.updatedAt)}` : ""}
      </p>
      <p className="notice-doc__body">{renderNoticeBody(notice.body, portalOrigin)}</p>
      <p className="text-4 notice-doc__source">
        {t("Published by the school on the portal.")}{" "}
        <Link to={`/notices/${notice.id}`} onClick={onClose}>
          {t("Open as a page")}
        </Link>
      </p>
    </Modal>
  );
}
