import { useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { Link, Navigate, NavLink, Outlet, useLocation } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { useAmbientMotion } from "../lib/motion";
import type { Me } from "../api/types";

import { DESKTOP_TABS, MOBILE_TABS } from "./navTabs";
import { ThemeDialog } from "./ThemeControls";

/** Route guard + chrome for every authed page. */
export function RequireAuth() {
  if (!api.hasSession()) return <Navigate to="/login" replace />;
  return <AppLayout />;
}

/** Topbar context per route — chrome only, no behavior. */
function pageContext(path: string): { eyebrow: string; title: string } {
  if (path.startsWith("/experiences/mine")) return { eyebrow: "Experiences", title: "My contributions" };
  if (path.startsWith("/experiences/compose")) return { eyebrow: "Experiences", title: "Share an experience" };
  if (path.startsWith("/experiences")) return { eyebrow: "Community", title: "Experiences" };
  if (path.startsWith("/timetable")) return { eyebrow: "Schedule", title: "Timetable" };
  if (path.startsWith("/history")) return { eyebrow: "Schedule", title: "History" };
  if (path.startsWith("/settings")) return { eyebrow: "Account", title: "Settings" };
  if (path.startsWith("/dash")) return { eyebrow: "Admin", title: "Dash" };
  return { eyebrow: "Today", title: "Home" };
}

function tabIndex(path: string, tabs: { to: string }[]): number {
  return tabs.findIndex((tab) => path === tab.to || path.startsWith(`${tab.to}/`));
}

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();
  const location = useLocation();
  const [themeOpen, setThemeOpen] = useState(false);
  useAmbientMotion();

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

  const ctx = pageContext(location.pathname);
  const railIndex = tabIndex(location.pathname, DESKTOP_TABS);
  const mobileIndex = tabIndex(location.pathname, MOBILE_TABS);

  return (
    <>
      {/* Desktop shell: fixed left rail — brand up top, numbered nav center,
          the active pill slides between items. Hidden ≤960px. */}
      <aside className="rail">
        <Link to="/home" className="brand">
          <span className="brand-mark" aria-hidden="true">
            H
          </span>
          HOney
        </Link>
        <nav className="rail-nav" aria-label="Primary">
          <span
            className="rail-pill"
            data-off={railIndex < 0 ? "true" : "false"}
            style={{ "--active": Math.max(railIndex, 0) } as CSSProperties}
            aria-hidden="true"
          />
          {DESKTOP_TABS.map((tab, i) => (
            <NavLink
              key={tab.to}
              to={tab.to}
              className={({ isActive }) => (isActive ? "nav-item is-active" : "nav-item")}
            >
              <span>{String(i + 1).padStart(2, "0")}</span>
              {tab.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Fixed blurred topbar: page context + appearance trigger + user menu. */}
      <header className="topbar">
        <div className="top-context">
          <span className="eyebrow">{ctx.eyebrow}</span>
          <strong>{ctx.title}</strong>
        </div>
        <button
          className="settings-trigger"
          type="button"
          aria-label="Appearance"
          onClick={() => setThemeOpen(true)}
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <circle cx="12" cy="12" r="3.2" />
            <path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M18.7 5.3l-1.4 1.4M6.7 17.3l-1.4 1.4" />
          </svg>
        </button>
        <UserMenu me={me} />
      </header>

      {/* Route-level settle: the keyed .view re-runs the entrance per route. */}
      <main className="main" id="main">
        <div className="view" key={location.pathname}>
          <Outlet />
        </div>
      </main>

      {/* Mobile shell (≤960px): floating pill nav, 4 slots, sliding active pill. */}
      <nav className="mobile-nav" aria-label="Primary">
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
    </>
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
    document.addEventListener("mousedown", onPointerDown);
    return () => document.removeEventListener("mousedown", onPointerDown);
  }, [open]);

  return (
    <div className="usermenu" ref={ref}>
      <button
        className="usermenu__button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
      >
        {me.displayName}
      </button>
      {open && (
        <div className="usermenu__panel" role="menu">
          <div className="usermenu__header">
            <strong>{me.displayName}</strong>
            <span className="caption">{me.honeyId}</span>
          </div>
          <Link className="usermenu__item" role="menuitem" to="/settings" onClick={() => setOpen(false)}>
            Settings
          </Link>
          {me.isAdmin && (
            <Link className="usermenu__item" role="menuitem" to="/dash" onClick={() => setOpen(false)}>
              Dash
            </Link>
          )}
          <button
            className="usermenu__item usermenu__item--danger"
            role="menuitem"
            onClick={() => void signOut()}
          >
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}
