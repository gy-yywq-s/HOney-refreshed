// Scroll model: FRAMED_SCROLL — the list scrolls, the page head frames it.
// /notices and /notices/:id — what the school published on the portal
// (Gary 2026-09-03). The school's words are shown verbatim, in the language
// the school wrote them; only HOney's own chrome switches language. New/read
// is a fact of THIS device (lib/noticesRead) and is never sent anywhere.

import { Link, useParams } from "react-router-dom";
import { api } from "../api/client";
import { useApi } from "../lib/useApi";
import { useRetryFocus } from "../lib/useRetryFocus";
import { Skeleton, staggerStyle } from "../lib/motion";
import { formatRelativeDay, formatTime } from "../lib/format";
import { markAllNoticesRead, markNoticeRead, useReadNotices } from "../lib/noticesRead";
import { ChevronRightIcon } from "../components/icons";
import { useT } from "../lib/i18n";
import { NoticeSheet, renderNoticeBody } from "../components/NoticeSheet";
import { useEffect, useState } from "react";

export function NoticesPage() {
  const { id } = useParams();
  const t = useT();
  const notices = useApi(() => api.notices(50), [], "notices");
  const landing = useRetryFocus<HTMLDivElement>(notices.loading);
  const read = useReadNotices();
  const list = notices.data?.notices ?? [];
  const one = id ? list.find((n) => n.id === id) : undefined;
  // A notice is read in a sheet; the page under /notices/:id stays for anyone
  // who wants it full-screen (Gary 2026-09-03).
  const [openId, setOpenId] = useState<string | null>(null);

  // Opening a notice reads it — on this device only.
  useEffect(() => {
    if (one) markNoticeRead(one.id);
  }, [one]);

  if (id) {
    return (
      <article className="doc notice-doc">
        {notices.loading ? (
          <Skeleton lines={6} />
        ) : one ? (
          <>
            <header>
              <h1 className="page-title notice-doc__title">{one.title}</h1>
              <p className="caption notice-doc__meta">
                {formatRelativeDay(one.postedAt)} · {formatTime(one.postedAt)}
                {one.updatedAt > one.postedAt ? ` · ${t("Edited")} ${formatRelativeDay(one.updatedAt)}` : ""}
              </p>
            </header>
            {/* The school's own text: plain, whitespace kept, never translated.
                Where the school wrote a file link, it becomes a real link to
                the portal — the words around it are untouched. */}
            <p className="notice-doc__body">{renderNoticeBody(one.body, notices.data?.portalOrigin ?? "")}</p>
            <p className="text-4 notice-doc__source">{t("Published by the school on the portal.")}</p>
          </>
        ) : (
          <>
            <h1 className="page-title">{t("Notice")}</h1>
            <p className="card empty">{t("This notice is no longer in the school's list.")}</p>
            <div className="card-actions">
              <Link className="btn btn--primary" to="/notices">
                {t("All notices")}
              </Link>
            </div>
          </>
        )}
      </article>
    );
  }

  const unread = list.filter((n) => !read.has(n.id));
  const open = openId ? list.find((n) => n.id === openId) : undefined;

  return (
    <div>
      <div className="page-head page-head--tools">
        <h1 className="page-title">{t("From school")}</h1>
        {unread.length > 0 && (
          <button className="btn btn--small btn--pill-ok" onClick={() => markAllNoticesRead(list.map((n) => n.id))}>
            {t("Mark all read")}
          </button>
        )}
      </div>

      <div ref={landing.ref} tabIndex={-1} className="focus-landing" role="region" aria-label="Notices">
        {notices.loading ? (
          <Skeleton lines={5} />
        ) : notices.error ? (
          <div role="alert" className="banner banner--danger">
            <span>{notices.error}</span>
            <button
              className="btn btn--ghost btn--small"
              onClick={() => {
                landing.arm();
                notices.reload();
              }}
            >
              {t("Try again")}
            </button>
          </div>
        ) : list.length === 0 ? (
          <p className="card empty">{t("The school has not published anything yet.")}</p>
        ) : (
          <ul className="notice-list">
            {list.map((n, i) => (
              <li className="notice-row stagger" style={staggerStyle(i)} key={n.id}>
                <button type="button" className="notice-row__link" onClick={() => setOpenId(n.id)}>
                  <span className="notice-row__main">
                    <span className="notice-row__title">
                      {!read.has(n.id) && <span className="notice-row__dot" aria-hidden="true" />}
                      {n.title}
                    </span>
                    <span className="caption notice-row__meta">{formatRelativeDay(n.postedAt)}</span>
                    <span className="caption notice-row__excerpt">{n.body.replace(/\s+/g, " ").slice(0, 90)}</span>
                  </span>
                  <span className="notice-row__chev">
                    <ChevronRightIcon size={18} />
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
      {open && (
        <NoticeSheet
          notice={open}
          portalOrigin={notices.data?.portalOrigin ?? ""}
          onClose={() => setOpenId(null)}
        />
      )}
    </div>
  );
}
