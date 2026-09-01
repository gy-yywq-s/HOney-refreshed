import { lazy, Suspense, useState } from "react";
import type { CSSProperties } from "react";
import {
  IonIcon,
  IonLabel,
  IonMenu,
  IonPopover,
  IonRouterOutlet,
  IonSplitPane,
  IonTabBar,
  IonTabButton,
  IonTabs,
} from "@ionic/react";
import { Link, Navigate, NavLink, Route, useLocation } from "react-router-dom";
import { api } from "../api/client";
import type { Me } from "../api/types";
import { useAuth } from "../auth/AuthContext";
import { IonicRoutePage } from "./IonicRoutePage";
import { DESKTOP_TABS, MOBILE_TABS } from "./navTabs";
import { ThemeDialog } from "./ThemeControls";
import { WordmarkHOney } from "./Wordmark";

const DashPage = lazy(() => import("../pages/DashPage").then((module) => ({ default: module.DashPage })));
const HistoryPage = lazy(() => import("../pages/HistoryPage").then((module) => ({ default: module.HistoryPage })));
const HomePage = lazy(() => import("../pages/HomePage").then((module) => ({ default: module.HomePage })));
const NotFoundPage = lazy(() => import("../pages/NotFoundPage").then((module) => ({ default: module.NotFoundPage })));
const SettingsPage = lazy(() => import("../pages/SettingsPage").then((module) => ({ default: module.SettingsPage })));
const TimetablePage = lazy(() => import("../pages/TimetablePage").then((module) => ({ default: module.TimetablePage })));
const ExperiencesComposePage = lazy(() => import("../pages/experiences/ComposePage").then((module) => ({ default: module.ExperiencesComposePage })));
const ExperienceEntityPage = lazy(() => import("../pages/experiences/EntityPage").then((module) => ({ default: module.ExperienceEntityPage })));
const ExperiencesExplorePage = lazy(() => import("../pages/experiences/ExplorePage").then((module) => ({ default: module.ExperiencesExplorePage })));
const ExperiencesFeedPage = lazy(() => import("../pages/experiences/FeedPage").then((module) => ({ default: module.ExperiencesFeedPage })));
const ExperiencesMinePage = lazy(() => import("../pages/experiences/MinePage").then((module) => ({ default: module.ExperiencesMinePage })));
const ExperiencesWhyPage = lazy(() => import("../pages/experiences/WhyPage").then((module) => ({ default: module.ExperiencesWhyPage })));

function RouteView({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<div className="fullscreen-note">Loading…</div>}>{children}</Suspense>;
}

/** Session guard + one responsive Ionic application shell. */
export function RequireAuth() {
  if (!api.hasSession()) return <Navigate to="/login" replace />;
  return <AppLayout />;
}

function tabIndex(path: string, tabs: { to: string }[]): number {
  return tabs.findIndex((tab) => path === tab.to || path.startsWith(`${tab.to}/`));
}

function AppLayout() {
  const { me, loading, error, refreshMe } = useAuth();
  const location = useLocation();
  const [themeOpen, setThemeOpen] = useState(false);

  if (!me) {
    return (
      <IonicRoutePage model="FIT" refreshable={false}>
        <div className="fullscreen-note">
          {loading ? (
            "Loading…"
          ) : (
            <div className="card">
              <p className="muted">{error ?? "Could not load your account."}</p>
              <button className="btn btn--primary" onClick={() => void refreshMe()}>
                Retry
              </button>
            </div>
          )}
        </div>
      </IonicRoutePage>
    );
  }

  const railIndex = tabIndex(location.pathname, DESKTOP_TABS);

  return (
    <IonSplitPane className="app-frame" contentId="ionic-main" when="(min-width: 961px)">
      <a className="skip-link" href="#ionic-main">
        Skip to content
      </a>
      <IonMenu className="honey-rail" contentId="ionic-main" type="overlay">
        <aside className="rail">
          <Link to="/home" className="brand" aria-label="HOney Home">
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
      </IonMenu>

      <div id="ionic-main" className="ionic-main" tabIndex={-1}>
        <IonTabs>
          <IonRouterOutlet animated>
            <Route path="/home" element={<IonicRoutePage model="COMPACT_OVERFLOW"><RouteView><HomePage /></RouteView></IonicRoutePage>} />
            <Route path="/timetable" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><TimetablePage /></RouteView></IonicRoutePage>} />
            <Route path="/history" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><HistoryPage /></RouteView></IonicRoutePage>} />
            <Route path="/history/lesson/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><HistoryPage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperiencesFeedPage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/explore" element={<IonicRoutePage model="FRAMED_EDITOR"><RouteView><ExperiencesExplorePage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/why" element={<IonicRoutePage model="DOCUMENT" refreshable={false}><RouteView><ExperiencesWhyPage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/mine" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperiencesMinePage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/compose" element={<IonicRoutePage model="FRAMED_EDITOR" refreshable={false}><RouteView><ExperiencesComposePage /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/teacher/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="teacher" /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/course/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="course" /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/room/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="room" /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/dish/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="dish" /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/place/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="room" /></RouteView></IonicRoutePage>} />
            <Route path="/experiences/food/:id" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><ExperienceEntityPage kind="dish" /></RouteView></IonicRoutePage>} />
            <Route path="/settings" element={<IonicRoutePage model="FRAMED_SCROLL"><RouteView><SettingsPage /></RouteView></IonicRoutePage>} />
            <Route
              path="/dash"
              element={
                <IonicRoutePage model="FRAMED_SCROLL">
                  <RouteView>
                    <DashPage />
                  </RouteView>
                </IonicRoutePage>
              }
            />
            <Route path="/" element={<Navigate to="/home" replace />} />
            <Route path="*" element={<IonicRoutePage model="DOCUMENT" refreshable={false}><RouteView><NotFoundPage /></RouteView></IonicRoutePage>} />
          </IonRouterOutlet>

          <IonTabBar className="mobile-nav" slot="bottom" aria-label="Primary, mobile">
            {MOBILE_TABS.map((tab) => (
              <IonTabButton key={tab.to} tab={tab.label.toLowerCase()} href={tab.to}>
                <IonIcon icon={tab.icon} aria-hidden="true" />
                <IonLabel>{tab.label}</IonLabel>
              </IonTabButton>
            ))}
          </IonTabBar>
        </IonTabs>
      </div>

      {themeOpen && <ThemeDialog onClose={() => setThemeOpen(false)} />}
    </IonSplitPane>
  );
}

function UserMenu({ me }: { me: Me }) {
  const { signOut } = useAuth();
  const [open, setOpen] = useState(false);
  const [popoverEvent, setPopoverEvent] = useState<Event>();

  return (
    <>
      <button
        id="account-popover-trigger"
        className="usermenu__button"
        onClick={(event) => {
          setPopoverEvent(event.nativeEvent);
          setOpen(true);
        }}
        aria-haspopup="menu"
        aria-expanded={open}
      >
        {me.displayName}
      </button>
      <IonPopover
        className="account-popover"
        event={popoverEvent}
        isOpen={open}
        onDidDismiss={() => setOpen(false)}
        dismissOnSelect
      >
          <div className="usermenu__panel usermenu__panel--ionic">
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
              onClick={() => {
                setOpen(false);
                void signOut();
              }}
            >
              Sign out
            </button>
          </div>
      </IonPopover>
    </>
  );
}
