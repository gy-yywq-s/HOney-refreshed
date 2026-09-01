import { useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { Link, Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
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

/** Topbar context per route — chrome only, no behavior. */

function tabIndex(path: string, tabs: { to: string }[]): number {
  return tabs.findIndex((tab) => path === tab.to || path.startsWith(`${tab.to}/`));
}

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();
  const location = useLocation();
  const [themeOpen, setThemeOpen] = useState(false);

  // The scroll owner persists across routes now (§16.14.3), so each route
  // change resets it to the top (review M3). Instant, not smooth: pages that
  // restore their own position (the feed) re-scroll in a later frame.
  useEffect(() => {
    const el = document.querySelector<HTMLElement>("[data-scroll-owner]");
    el?.scrollTo({ top: 0, behavior: "instant" });
    const p = location.pathname;
    const name =
      p === "/home" ? "Home"
      : p === "/timetable" ? "Timetable"
      : p === "/history" ? "History"
      : p === "/settings" ? "Settings"
      : p === "/dash" ? "Dash"
      : p.startsWith("/experiences/compose") ? "Share an experience"
      : p.startsWith("/experiences/explore") ? "Find someone or something"
      : p.startsWith("/experiences/mine") ? "Your notes & posts"
      : p.startsWith("/experiences/why") ? "Why this space exists"
      : p.startsWith("/experiences") ? "Experiences"
      : null;
    document.title = name ? `${name} · HOney` : "HOney";
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
              className={({ isActive }) => (isActive ? "nav-item is-active" : "nav-item")}
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
            className={({ isActive }) =>
              isActive ? "mobile-nav__item is-active" : "mobile-nav__item"
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
