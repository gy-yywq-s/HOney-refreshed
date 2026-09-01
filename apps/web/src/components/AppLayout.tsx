import { useEffect, useRef, useState } from "react";
import { Link, Navigate, NavLink, Outlet } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import type { Me } from "../api/types";

import { DESKTOP_TABS, MOBILE_TABS } from "./navTabs";

/** Route guard + chrome for every authed page. */
export function RequireAuth() {
  if (!api.hasSession()) return <Navigate to="/login" replace />;
  return <AppLayout />;
}

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();

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

  return (
    <>
      <header className="topnav">
        <div className="topnav__inner">
          <Link to="/home" className="topnav__brand">
            HOney
          </Link>
          <nav className="topnav__tabs" aria-label="Primary">
            {DESKTOP_TABS.map((tab) => (
              <NavLink
                key={tab.to}
                to={tab.to}
                className={({ isActive }) =>
                  isActive ? "topnav__tab topnav__tab--active" : "topnav__tab"
                }
              >
                {tab.label}
              </NavLink>
            ))}
          </nav>
          <UserMenu me={me} />
        </div>
      </header>
      <main className="container">
        <Outlet />
      </main>
      {/* Mobile shell: fixed bottom tab bar, styled like the iOS TabView.
          CSS hides it >640px and hides the top nav at <=640px. */}
      <nav className="tabbar" aria-label="Primary">
        {MOBILE_TABS.map((tab) => (
          <NavLink
            key={tab.to}
            to={tab.to}
            className={({ isActive }) =>
              isActive ? "tabbar__item tabbar__item--active" : "tabbar__item"
            }
          >
            {tab.icon}
            <span>{tab.label}</span>
          </NavLink>
        ))}
      </nav>
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
