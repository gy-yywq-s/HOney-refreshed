import { useCallback, useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { Link, Navigate, NavLink, Outlet, useLocation, useNavigate, useNavigationType } from "react-router-dom";
import { isKnownRoute, parentOf, rootOf, titleOf } from "../lib/navigation";
import { api } from "../api/client";
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

// In-app history, one entry per visited screen, so the back bar can POP
// when the parent is the previous entry (the native feel) and otherwise
// go up by REPLACING — never pushing a loop of parent/child/parent.
const stack: string[] = [];

const EDGE_PX = 28; // a swipe that starts this close to the left edge
const SWIPE_PX = 72; // and travels this far right, mostly horizontally

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const navType = useNavigationType();
  const [themeOpen, setThemeOpen] = useState(false);

  const parent = parentOf(location.pathname, location.search);
  const parentRef = useRef(parent);
  parentRef.current = parent;

  useEffect(() => {
    const here = location.pathname;
    if (navType === "PUSH") stack.push(here);
    else if (navType === "REPLACE") stack[Math.max(0, stack.length - 1)] = here;
    else if (stack.length >= 2 && stack[stack.length - 2] === here) stack.pop();
    else if (stack[stack.length - 1] !== here) stack.push(here);
  }, [location.key, location.pathname, navType]);

  const goUp = useCallback(() => {
    const up = parentRef.current;
    if (!up) return;
    if (stack.length >= 2 && stack[stack.length - 2] === up.to) navigate(-1);
    else navigate(up.to, { replace: true });
  }, [navigate]);

  // Left-edge swipe = up one level (standalone iOS has no browser gesture;
  // in a browser the OS consumes the edge before we see it).
  useEffect(() => {
    let startX = 0;
    let startY = 0;
    let armed = false;
    let fired = false;
    const onStart = (e: TouchEvent) => {
      const t = e.touches[0]!;
      const target = e.target as Element | null;
      armed = t.clientX <= EDGE_PX && !!parentRef.current && !target?.closest(".modal-overlay");
      fired = false;
      startX = t.clientX;
      startY = t.clientY;
    };
    const onMove = (e: TouchEvent) => {
      if (!armed || fired) return;
      const t = e.touches[0]!;
      const dx = t.clientX - startX;
      const dy = Math.abs(t.clientY - startY);
      if (dy > 48 && dy > dx) armed = false;
      else if (dx >= SWIPE_PX && dx > dy * 1.5) {
        fired = true;
        goUp();
      }
    };
    const onEnd = () => {
      armed = false;
    };
    document.addEventListener("touchstart", onStart, { passive: true });
    document.addEventListener("touchmove", onMove, { passive: true });
    document.addEventListener("touchend", onEnd, { passive: true });
    document.addEventListener("touchcancel", onEnd, { passive: true });
    return () => {
      document.removeEventListener("touchstart", onStart);
      document.removeEventListener("touchmove", onMove);
      document.removeEventListener("touchend", onEnd);
      document.removeEventListener("touchcancel", onEnd);
    };
  }, [goUp]);

  // The scroll owner persists across routes now (§16.14.3), so each route
  // change resets it to the top (review M3). Instant, not smooth: pages that
  // restore their own position (the feed) re-scroll in a later frame.
  useEffect(() => {
    const el = document.querySelector<HTMLElement>("[data-scroll-owner]");
    el?.scrollTo({ top: 0, behavior: "instant" });
    const name = titleOf(location.pathname);
    if (name) document.title = `${name} · HOney`;
  }, [location.pathname]);

  if (!me) {
    if (loading) return <div className="fullscreen-note">Loading…</div>;
    return (
      <div className="fullscreen-note">
        <div className="card">
          <p className="muted">{error ?? "Could not load your account."}</p>
          <button className="btn btn--primary" onClick={() => void refreshMe()}>
            Retry
          </button>
        </div>
      </div>
    );
  }

  const known = isKnownRoute(location.pathname);
  const railIndex = tabIndex(location.pathname, DESKTOP_TABS);
  const mobileIndex = tabIndex(location.pathname, MOBILE_TABS);

  return (
    <div className="app-frame">
      <a className="skip-link" href="#main">
        Skip to content
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
          {DESKTOP_TABS.map((tab) => (
            <NavLink
              key={tab.to}
              to={tab.to}
              replace
              className={({ isActive }) => (isActive && known ? "nav-item is-active" : "nav-item")}
              aria-current={undefined}
            >
              {tab.label}
            </NavLink>
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
          <UserMenu me={me} />
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
                to={parent.to}
                onClick={(e) => {
                  e.preventDefault();
                  goUp();
                }}
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M15 5l-7 7 7 7" />
                </svg>
                <span>{parent.title}</span>
              </Link>
            </nav>
          )}
          <Outlet />
        </div>
      </main>

      {/* Mobile shell (≤960px): floating pill nav, 4 slots, sliding active pill. */}
      <nav className="mobile-nav" aria-label="Primary, mobile">
        <span
          className="mobile-nav__pill"
          data-off={mobileIndex < 0 ? "true" : "false"}
          style={{ "--active": Math.max(mobileIndex, 0) } as CSSProperties}
          aria-hidden="true"
        />
        {MOBILE_TABS.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            replace
            className={({ isActive }) =>
              isActive && known ? "mobile-nav__item is-active" : "mobile-nav__item"
            }
          >
            {tab.icon}
            <span>{tab.label}</span>
          </NavLink>
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
