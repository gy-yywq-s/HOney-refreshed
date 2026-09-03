import { useCallback, useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { Link, Navigate, Outlet, useLocation, useNavigate, useNavigationType } from "react-router-dom";
import { parentOf, rootOf, titleOf } from "../lib/navigation";
import { useRetryFocus } from "../lib/useRetryFocus";
import { useT } from "../lib/i18n";
import { Skeleton } from "../lib/motion";
import { api } from "../api/client";
import { accessClient } from "../lib/access/client";
import { useAuth } from "../auth/AuthContext";
import type { Me } from "../api/types";

import { DESKTOP_TABS, MOBILE_TABS } from "./navTabs";
import { PullToRefresh } from "./PullToRefresh";
import { WordmarkHOney } from "./Wordmark";
import { ThemeDialog } from "./ThemeControls";

/** Route guard + chrome for every authed page. */
export function RequireAuth() {
  if (!api.hasSession()) return <Navigate to="/login" replace />;
  return <AppLayout />;
}

/** The tab of the screen's ROOT ancestor (History lights Timetable). */
function tabIndex(path: string, tabs: { to: string }[]): number {
  const root = rootOf(path);
  return root ? tabs.findIndex((tab) => tab.to === root) : -1;
}

// In-app history: one entry per visited screen with its title and scroll
// position (Gary 2026-09-02: "the same as a native app"). The back bar and
// the OS back gesture then AGREE — both pop to where you came from — and a
// popped screen comes back where it was, without the entrance animation.
// The route tree (lib/navigation.ts) only names the way up on a cold deep
// link, where there is nothing to pop to.
interface StackEntry {
  path: string;
  title: string;
  scroll: number;
}
const stack: StackEntry[] = [];
function titleNow(): string {
  return document.title.replace(/ · HOney$/, "");
}

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const navType = useNavigationType();
  const [themeOpen, setThemeOpen] = useState(false);
  const t = useT();

  const parent = parentOf(location.pathname, location.search);
  const parentRef = useRef(parent);
  parentRef.current = parent;

  // Warm the Access tab once per session (its bootstrap reads the school
  // portal, ~2–3 s): the first tap then shows content at once. Read-only —
  // no physical operation is ever prepared here.
  useEffect(() => {
    if (!me?.connection.connected || accessClient.cachedBootstrap()) return;
    void accessClient.bootstrap().catch(() => undefined);
  }, [me?.connection.connected]);

  // iOS scrolls the WINDOW to a focused control — a native <select> wheel, a
  // field under a sheet — even though this shell never window-scrolls (the
  // .main region is the scroll owner). The page is then left drifted, with a
  // fixed overlay sitting off the viewport (Gary 2026-09-03: 屏幕整个溢出然后
  // 漂移). Whenever the document itself is not scrollable, put it back.
  useEffect(() => {
    const settle = () => {
      if (document.documentElement.scrollHeight > window.innerHeight + 1) return;
      if (window.scrollY !== 0 || window.scrollX !== 0) window.scrollTo(0, 0);
    };
    const vv = window.visualViewport;
    window.addEventListener("focusin", settle);
    window.addEventListener("focusout", settle);
    window.addEventListener("scroll", settle, { passive: true });
    vv?.addEventListener("resize", settle);
    vv?.addEventListener("scroll", settle);
    return () => {
      window.removeEventListener("focusin", settle);
      window.removeEventListener("focusout", settle);
      window.removeEventListener("scroll", settle);
      vv?.removeEventListener("resize", settle);
      vv?.removeEventListener("scroll", settle);
    };
  }, []);

  const [back, setBack] = useState<StackEntry | null>(null);
  useEffect(() => {
    const here = location.pathname;
    const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
    let restore = 0;
    let popped = false;
    if (navType === "PUSH") stack.push({ path: here, title: "", scroll: 0 });
    else if (navType === "REPLACE") stack[Math.max(0, stack.length - 1)] = { path: here, title: "", scroll: 0 };
    else if (stack.length >= 2 && stack[stack.length - 2]!.path === here) {
      stack.pop();
      popped = true;
      restore = stack[stack.length - 1]!.scroll;
    } else if (stack[stack.length - 1]?.path !== here) stack.push({ path: here, title: "", scroll: 0 });
    else {
      popped = true;
      restore = stack[stack.length - 1]!.scroll;
    }
    // A popped screen returns where it was and does not re-enter; a pushed
    // one starts at the top and settles in.
    document.documentElement.dataset.nav = popped ? "pop" : "push";
    if (owner) {
      owner.style.scrollBehavior = "auto";
      owner.scrollTop = 0;
      requestAnimationFrame(() =>
        requestAnimationFrame(() => {
          if (popped) owner.scrollTop = restore;
          owner.style.scrollBehavior = "";
        }),
      );
    }
    const name = titleOf(here);
    if (name) document.title = `${name} · HOney`;
    setBack(stack.length >= 2 ? stack[stack.length - 2]! : null);
  }, [location.key, location.pathname, navType]);

  // Each entry remembers the title the screen ended up with (entity pages
  // set theirs after loading) and where it was scrolled to.
  useEffect(() => {
    const el = document.querySelector("title");
    const sync = () => {
      const top = stack[stack.length - 1];
      if (top) top.title = titleNow();
    };
    sync();
    if (!el) return;
    const mo = new MutationObserver(sync);
    mo.observe(el, { childList: true, characterData: true, subtree: true });
    return () => mo.disconnect();
  }, [location.key]);
  useEffect(() => {
    const owner = document.querySelector<HTMLElement>("[data-scroll-owner]");
    if (!owner) return;
    const onScroll = () => {
      const top = stack[stack.length - 1];
      if (top) top.scroll = owner.scrollTop;
    };
    owner.addEventListener("scroll", onScroll, { passive: true });
    return () => owner.removeEventListener("scroll", onScroll);
  }, []);

  // Up: pop when there is somewhere to pop to (the OS gesture does the same);
  // otherwise the tree's parent, replacing — never a parent/child loop.
  const goUp = useCallback(() => {
    if (stack.length >= 2) {
      navigate(-1);
      return;
    }
    const up = parentRef.current;
    if (up) navigate(up.to, { replace: true });
  }, [navigate]);
  const backLabel = back ? back.title || titleOf(back.path) || "Back" : parent?.title ?? "";
  const backTo = back ? back.path : (parent?.to ?? "/home");

  // The scroll owner persists across routes now (§16.14.3), so each route
  // change resets it to the top (review M3). Instant, not smooth: pages that
  // restore their own position (the feed) re-scroll in a later frame.

  // The account request failing must not replace the app (r10): the shell
  // stays — nav, skip link, scroll owner — with one alert and a landing retry.
  const shellLanding = useRetryFocus<HTMLDivElement>(loading);
  const shellFallback = !me ? (
    <div className="focus-landing shell-fallback" ref={shellLanding.ref} tabIndex={-1} role="region" aria-label="Your account">
      {loading ? (
        <Skeleton lines={3} />
      ) : (
        <div role="alert" className="banner banner--danger">
          <span>{error ?? t("Could not load your account.")}</span>
          <button
            className="btn btn--ghost btn--small"
            onClick={() => {
              shellLanding.arm();
              void refreshMe();
            }}
          >
            {t("Try again")}
          </button>
        </div>
      )}
    </div>
  ) : null;

  const railIndex = tabIndex(location.pathname, DESKTOP_TABS);
  const mobileIndex = tabIndex(location.pathname, MOBILE_TABS);

  return (
    <div className="app-frame">
      <a className="skip-link" href="#main">
        {t("Skip to content")}
      </a>
      {/* Desktop shell: fixed left rail — brand up top, numbered nav center,
          the active pill slides between items. Hidden ≤960px. */}
      <aside className="rail">
        <Link to="/home" className="brand">
          <WordmarkHOney height={26} />
        </Link>
        <nav className="rail-nav" aria-label="Primary">
          <span
            className="rail-pill"
            data-off={railIndex < 0 ? "true" : "false"}
            style={{ "--active": Math.max(railIndex, 0) } as CSSProperties}
            aria-hidden="true"
          />
          {DESKTOP_TABS.map((tab, i) => (
            <Link
              key={tab.to}
              to={tab.to}
              replace
              className={i === railIndex ? "nav-item is-active" : "nav-item"}
              aria-current={i === railIndex ? "page" : undefined}
            >
              {tab.label}
            </Link>
          ))}
        </nav>
        {/* No topbar: appearance + account live at the rail's foot (Gary,
            2026-09-01 — the bar duplicated the nav and the pages' own titles).
            On mobile both live in the Settings tab instead. */}
        <div className="rail-foot">
          <button
            className="settings-trigger"
            type="button"
            aria-label="Appearance"
            title="Appearance"
            onClick={() => setThemeOpen(true)}
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="12" cy="12" r="3.2" />
              <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M18.7 5.3l-1.4 1.4M6.7 17.3l-1.4 1.4" />
            </svg>
          </button>
          {me && <UserMenu me={me} />}
        </div>
      </aside>

      {/* Route-level settle: the keyed .view re-runs the entrance per route.
          THE scroll owner (§16.14.3): the app frame owns the viewport; only
          this region scrolls. data-scroll-owner is the restoration handle. */}
      <main className="main" id="main" data-scroll-owner tabIndex={-1}>
        <PullToRefresh />
        <div className="view" key={location.pathname}>
          {parent && (
            <nav className="pagebar" aria-label="Up one level">
              <Link
                className="pagebar__back"
                to={backTo}
                onClick={(e) => {
                  e.preventDefault();
                  goUp();
                }}
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M15 5l-7 7 7 7" />
                </svg>
                <span className="sr-only">{t("Back to ")}</span>
                <span>{backLabel}</span>
              </Link>
            </nav>
          )}
          {shellFallback ?? <Outlet />}
        </div>
      </main>

      {/* Mobile shell (≤960px): floating pill nav, one slot per tab, sliding active pill. */}
      <nav className="mobile-nav" aria-label="Primary, mobile" style={{ "--tabs": MOBILE_TABS.length } as CSSProperties}>
        <span
          className="mobile-nav__pill"
          data-off={mobileIndex < 0 ? "true" : "false"}
          style={{ "--active": Math.max(mobileIndex, 0) } as CSSProperties}
          aria-hidden="true"
        />
        {MOBILE_TABS.map((tab, i) => (
          <Link
            key={tab.to}
            to={tab.to}
            replace
            className={i === mobileIndex ? "mobile-nav__item is-active" : "mobile-nav__item"}
            aria-current={i === mobileIndex ? "page" : undefined}
          >
            {tab.icon}
            <span>{tab.label}</span>
          </Link>
        ))}
      </nav>

      {themeOpen && <ThemeDialog onClose={() => setThemeOpen(false)} />}
    </div>
  );
}

function UserMenu({ me }: { me: Me }) {
  const { signOut } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    // Escape closes and returns focus to the trigger (design audit, fix 10).
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setOpen(false);
        ref.current?.querySelector("button")?.focus();
      }
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div className="usermenu" ref={ref}>
      <button
        className="usermenu__button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="true"
        aria-expanded={open}
      >
        {me.displayName}
      </button>
      {open && (
        <div className="usermenu__panel">
          <div className="usermenu__header">
            <strong>{me.displayName}</strong>
            <span className="caption">{me.honeyId}</span>
          </div>
          <Link className="usermenu__item" to="/settings" onClick={() => setOpen(false)}>
            Settings
          </Link>
          {me.isAdmin && (
            <Link className="usermenu__item" to="/dash" onClick={() => setOpen(false)}>
              Dash
            </Link>
          )}
          <button
            className="usermenu__item usermenu__item--danger"
           
            onClick={() => void signOut()}
          >
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}
