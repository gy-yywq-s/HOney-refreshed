// Home has ONE job (review v3 §6.2): know what's now / next in three seconds,
// and lightly feel that other students are speaking. Composition (§6.3):
// compact greeting + date → focal Now/Next object → 1–2 raw experience
// previews → the composer prompt → a quiet School Portal row. No stat
// strips, no numbered action grid, no feature copy.
// Scroll model: COMPACT_OVERFLOW.
//
// Zones (Gary, 2026-09-02): three, each parted by a hairline — the lesson,
// the voices from your classes (with the way to add yours inside it), the
// portal. Sharing is not a lone button: it is a composer prompt at the foot
// of the voices — the home-page publish entry social apps share ("What's
// new?" / "Start a post") — so it reads as joining what is above it. No
// "last updated … ago" on a Home card; Settings carries that.

import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api/client";
import { ReconnectDialog } from "../components/ReconnectDialog";
import { useAuth } from "../auth/AuthContext";
import { useApi } from "../lib/useApi";
import { useRetryFocus } from "../lib/useRetryFocus";
import { formatDayBucket, formatDayTitle, formatRemaining, formatTime } from "../lib/format";
import { lessonTitle, roomLabel } from "../lib/displayNames";
import { ChevronRightIcon, PenIcon } from "../components/icons";
import { WordmarkHOney } from "../components/Wordmark";
import { useLang, useT } from "../lib/i18n";
import { Skeleton, useNowTick } from "../lib/motion";
import { useFromYourClasses } from "./experiences/shared";
import { usePortalEntry } from "../lib/portalEntry";

/** Running as the installed (standalone) app, not in a browser tab. */
function isStandalone(): boolean {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true;
}

export function HomePage() {
  const { me } = useAuth();
  const { data, error, loading, reload } = useApi(() => api.nextLesson(), [], "next-lesson");
  const landing = useRetryFocus<HTMLElement>(loading);
  const fromClasses = useFromYourClasses(10);
  const now = useNowTick(1000);
  const t = useT();
  const lang = useLang();
  const portal = usePortalEntry();
  const [portalLogin, setPortalLogin] = useState(false);
  const standalone = isStandalone();

  if (!me) return null;

  const next = data?.nextLesson ?? null;
  // Legacy behavior kept: a running lesson fills the focal object with an
  // accent wash, left-to-right, proportional to elapsed time — motion that
  // explains state (review v3 §5.5.3 keeps exactly this kind).
  const progress =
    next && next.temporalState === "now"
      ? Math.min(1, Math.max(0, (now - next.startsAt) / Math.max(1, next.endsAt - next.startsAt)))
      : null;
  // One temporal sentence across the card (review v1.1 §4.4 A): the state
  // on the left, the relative time on the right. Humanized: "In 45 min"
  // same-day, "Tomorrow · 13:30" / "Thursday · 13:30" beyond — never
  // "In 618 min" (Gary + copy audit 2026-09-01).
  const isNow = next?.temporalState === "now";
  const sameDay = !!next && new Date(next.startsAt).toDateString() === new Date(now).toDateString();
  const when = (() => {
    if (!next) return null;
    if (isNow) return `${formatRemaining(next.endsAt - now)} ${t("left")}`;
    if (sameDay) return `${t("In")} ${formatRemaining(next.startsAt - now)}`;
    const start = new Date(next.startsAt);
    const tomorrow = start.toDateString() === new Date(now + 86_400_000).toDateString();
    const day = tomorrow ? t("Tomorrow") : start.toLocaleDateString("en-GB", { weekday: "long" });
    return `${day} · ${formatTime(next.startsAt)}`;
  })();
  const soon = !!next && !isNow && sameDay && next.startsAt - now < 10 * 60_000;
  const stateLabel = isNow ? t("Now") : t("Next lesson");
  const cardName = next
    ? [
        `${stateLabel}: ${lessonTitle(next)}`,
        `${formatTime(next.startsAt)} to ${formatTime(next.endsAt)}`,
        next.teacherName,
        roomLabel(next.roomName),
        when,
      ]
        .filter(Boolean)
        .join(", ") + ". Open timetable"
    : `${t("Nothing coming up")}. Open timetable`;

  // The same string as the Timetable's own heading — one formatter (r10).
  const today = formatDayTitle(new Date(now).toLocaleDateString("en-CA"));
  const previews = (fromClasses.experiences ?? []).filter((e) => e.body).slice(0, 2);

  return (
    <div className="stack home">
      {/* The wordmark sits on the greeting line, at the right and small
          (Gary 2026-09-03, the iPhone reference) — no brand bar. Hidden
          where the rail already carries it. */}
      <header className="home-head">
        <div className="home-head__row">
          <h1 className="home-head__hi">{lang === "zh" ? `你好，${me.displayName}` : `Hi, ${me.displayName}`}</h1>
          <span className="home-head__mark" aria-hidden="true">
            <WordmarkHOney height={22} />
          </span>
        </div>
        <p className="home-head__date">{today}</p>
      </header>

      {/* The Now/Next object (review v1.1 §4.3): one temporal header, one
          subject block, one structured details row; the whole card is the
          navigation target. The slot keeps its height across states. */}
      <section
        className="nextlesson-slot focus-landing"
        aria-label="Now and next"
        role="region"
        ref={landing.ref}
        tabIndex={-1}
      >
        {loading ? (
          <div className="card card--hero nextlesson" aria-busy="true">
            <div className="nextlesson__head">
              <span className="nextlesson__label">{t("Next lesson")}</span>
            </div>
            <Skeleton lines={2} />
          </div>
        ) : error ? (
          <div role="alert" className="banner banner--danger">
            <span>{error}</span>
            <button className="btn btn--ghost btn--small" onClick={() => { landing.arm(); reload(); }}>
              {t("Try again")}
            </button>
          </div>
        ) : next ? (
          <Link
            className={isNow ? "card card--hero nextlesson nextlesson--live" : "card card--hero nextlesson"}
            to={`/timetable?date=${new Date(next.startsAt).toLocaleDateString("en-CA")}`}
            aria-label={cardName}
          >
            {progress !== null && (
              <div
                className="nextlesson__wash"
                style={{ width: `${(progress * 100).toFixed(1)}%` }}
                aria-hidden="true"
              />
            )}
            <div className="nextlesson__head">
              <span className="nextlesson__label">{stateLabel}</span>
              {when && (
                <span className={soon ? "nextlesson__when nextlesson__when--soon" : "nextlesson__when"}>
                  {when}
                </span>
              )}
            </div>
            <div className="nextlesson__subject">{lessonTitle(next)}</div>
            <div className="nextlesson__details">
              <span className="nextlesson__time">
                {formatTime(next.startsAt)}–{formatTime(next.endsAt)}
              </span>
              {(next.teacherName || next.roomName) && (
                <span className="nextlesson__who">
                  {next.teacherName && <span className="nextlesson__teacher">{next.teacherName}</span>}
                  {next.roomName && <span className="nextlesson__room">{roomLabel(next.roomName)}</span>}
                </span>
              )}
            </div>
            <span className="nextlesson__chev">
              <ChevronRightIcon size={18} />
            </span>
          </Link>
        ) : (
          <Link className="card card--hero nextlesson nextlesson--empty" to="/timetable" aria-label={cardName}>
            <div className="nextlesson__head">
              <span className="nextlesson__label">{t("Nothing coming up")}</span>
            </div>
            <div className="nextlesson__subject">{t("No upcoming lessons in your timetable.")}</div>
            <span className="nextlesson__chev">
              <ChevronRightIcon size={18} />
            </span>
          </Link>
        )}
      </section>

      <section className="home-voices home-zone" aria-label="Related to you">
        <div className="home-voices__head">
          <span className="eyebrow">{t("Related to you")}</span>
        </div>
        {fromClasses.loading ? (
          <Skeleton lines={2} />
        ) : fromClasses.error || previews.length === 0 ? (
          <p className="muted home-voices__empty">
            {t("When someone shares an experience connected to your classes, it will appear here.")}
          </p>
        ) : (
          <ul className="home-voices__list">
            {/* Chronological, 1–2 only — a glimpse, not a mini feed (§6.4). */}
            {previews.map((exp) => (
              <li key={exp.id} className="home-voices__row">
                <Link to="/experiences" className="home-voices__body">
                  {exp.body}
                </Link>
                <span className="caption">
                  {[
                    exp.contexts?.find((c) => c.type === "course")?.name,
                    exp.contexts?.find((c) => c.type === "teacher")?.name ??
                      (exp.primary?.type !== "lesson" ? exp.primary?.name : null),
                  ]
                    .filter(Boolean)
                    .join(" · ")}
                  {exp.publishedDay !== null ? ` · ${formatDayBucket(exp.publishedDay)}` : ""}
                </span>
              </li>
            ))}
          </ul>
        )}
        {/* The composer prompt: the way to add your own voice lives with the
            voices, styled as a quiet field rather than a button. */}
        <Link className="composer-prompt" to="/experiences/compose" aria-label={t("Share an experience")}>
          <span className="composer-prompt__glyph" aria-hidden="true">
            <PenIcon size={16} />
          </span>
          <span className="composer-prompt__text">{t("Share what a lesson was like…")}</span>
        </Link>
      </section>

      <div className="home-foot home-zone">
        {/* Opens the portal SIGNED IN: the href carries HOney's live portal
            token to the portal's own login page (lib/portalEntry). */}
        {portal.needsLogin ? (
          /* HOney cannot enter signed in and nothing here can renew: ask for
             the school login once (kept on this device), never land the
             student on the portal's own login page. */
          <button type="button" className="portal-row" onClick={() => setPortalLogin(true)}>
            <img className="portal-row__icon" src="/oasis.png" alt="" width="22" height="22" />
            <span className="portal-row__title">School Portal</span>
            <span className="caption">{t("Sign in once to open")}</span>
          </button>
        ) : (
          <a className="portal-row" href={portal.href} target="_blank" rel="noopener noreferrer">
            <img className="portal-row__icon" src="/oasis.png" alt="" width="22" height="22" />
            <span className="portal-row__title">School Portal</span>
            {/* In the installed app the row says what it does: it enters the
                portal signed in, here — not a jump to the outside (Gary 2026-09-03). */}
            <span className="caption">
              {standalone ? t("Signed in · no login needed") : (
                <>
                  {t("Open the official site")} <span aria-hidden="true">&#8599;</span>
                </>
              )}
            </span>
          </a>
        )}
      </div>
      {portalLogin && (
        <ReconnectDialog
          purpose="reconnect"
          onClose={() => setPortalLogin(false)}
          onReconnected={() => portal.refresh()}
        />
      )}
    </div>
  );
}
