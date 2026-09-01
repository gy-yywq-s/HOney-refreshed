import { lazy, Suspense } from "react";
import {
  IonApp,
  IonContent,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonMenu,
  IonMenuToggle,
  IonRouterOutlet,
  IonSplitPane,
  IonTabBar,
  IonTabButton,
  IonTabs,
} from "@ionic/react";
import { IonReactRouter } from "@ionic/react-router";
import { calendarOutline, homeOutline, peopleOutline, personCircleOutline } from "ionicons/icons";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import { AuthProvider, useAuth } from "./auth/AuthContext";
import { Wordmark } from "./components/Wordmark";
import { LoginPage } from "./pages/LoginPage";
import { ConsentPage } from "./pages/ConsentPage";

const AccessPage = lazy(() => import("./pages/AccessPage").then((module) => ({ default: module.AccessPage })));
const ComposePage = lazy(() => import("./pages/ComposePage").then((module) => ({ default: module.ComposePage })));
const EntityPage = lazy(() => import("./pages/EntityPage").then((module) => ({ default: module.EntityPage })));
const ExperiencesPage = lazy(() => import("./pages/ExperiencesPage").then((module) => ({ default: module.ExperiencesPage })));
const ExplorePage = lazy(() => import("./pages/ExplorePage").then((module) => ({ default: module.ExplorePage })));
const HistoryPage = lazy(() => import("./pages/HistoryPage").then((module) => ({ default: module.HistoryPage })));
const HomePage = lazy(() => import("./pages/HomePage").then((module) => ({ default: module.HomePage })));
const LessonDetailPage = lazy(() => import("./pages/LessonDetailPage").then((module) => ({ default: module.LessonDetailPage })));
const MinePage = lazy(() => import("./pages/MinePage").then((module) => ({ default: module.MinePage })));
const NotFoundPage = lazy(() => import("./pages/NotFoundPage").then((module) => ({ default: module.NotFoundPage })));
const PrivacyPage = lazy(() => import("./pages/PrivacyPage").then((module) => ({ default: module.PrivacyPage })));
const SettingsPage = lazy(() => import("./pages/SettingsPage").then((module) => ({ default: module.SettingsPage })));
const TimetablePage = lazy(() => import("./pages/TimetablePage").then((module) => ({ default: module.TimetablePage })));
const WhyPage = lazy(() => import("./pages/WhyPage").then((module) => ({ default: module.WhyPage })));

export function App() {
  return <IonApp><IonReactRouter><AuthProvider><a className="skip-link" href="#main-view">Skip to content</a><main id="main-view" className="route-main" tabIndex={-1}><Suspense fallback={<div className="app-loading" role="status">Opening this page…</div>}><Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/consent" element={<ConsentPage />} />
    <Route path="/*" element={<AuthenticatedApp />} />
  </Routes></Suspense></main></AuthProvider></IonReactRouter></IonApp>;
}

function AuthenticatedApp() {
  const { me, loading, fixtureMode } = useAuth();
  if (loading) return <div className="app-loading" role="status">Opening HOney…</div>;
  if (!me) return <Navigate to="/login" replace />;
  return <>{fixtureMode && <div className="demo-strip">Fixture data · not live</div>}<AppShell /></>;
}

const nav = [
  { label: "Home", path: "/home", icon: homeOutline },
  { label: "Experiences", path: "/experiences", icon: peopleOutline },
  { label: "Timetable", path: "/timetable", icon: calendarOutline },
];

function AppShell() {
  const route = useLocation();
  return <IonSplitPane contentId="main-content" when="(min-width: 1024px)">
    <IonMenu className="app-menu" contentId="main-content" type="reveal">
      <div className="menu-head"><Wordmark /><p>School, with more context.</p></div>
      <IonContent><IonList className="menu-list" lines="none">{nav.map((item) => <IonMenuToggle key={item.path} autoHide={false}><IonItem className={route.pathname.startsWith(item.path) ? "active" : ""} button routerLink={item.path} routerDirection="root"><IonIcon slot="start" icon={item.icon} /><IonLabel>{item.label}</IonLabel></IonItem></IonMenuToggle>)}</IonList></IonContent>
      <div className="menu-foot"><IonMenuToggle autoHide={false}><IonItem button lines="none" routerLink="/settings"><IonIcon slot="start" icon={personCircleOutline} /><IonLabel>Settings</IonLabel></IonItem></IonMenuToggle></div>
    </IonMenu>
    <div id="main-content" className="ionic-content-host">
      <IonTabs>
        <IonRouterOutlet>
        <Route path="/home" element={<HomePage />} />
        <Route path="/experiences" element={<ExperiencesPage />} />
        <Route path="/experiences/explore" element={<ExplorePage />} />
        <Route path="/experiences/why" element={<WhyPage />} />
        <Route path="/experiences/mine" element={<MinePage />} />
        <Route path="/experiences/compose" element={<ComposePage />} />
        <Route path="/experiences/teacher/:id" element={<EntityPage type="teacher" />} />
        <Route path="/experiences/course/:id" element={<EntityPage type="course" />} />
        <Route path="/experiences/room/:id" element={<EntityPage type="room" />} />
        <Route path="/experiences/dish/:id" element={<EntityPage type="dish" />} />
        <Route path="/timetable" element={<TimetablePage />} />
        <Route path="/history" element={<HistoryPage />} />
        <Route path="/history/lesson/:id" element={<LessonDetailPage />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/privacy" element={<PrivacyPage />} />
        <Route path="/access" element={<AccessPage />} />
        <Route path="/" element={<Navigate to="/home" replace />} />
        <Route path="*" element={<NotFoundPage />} />
        </IonRouterOutlet>
        <IonTabBar className="honey-tabbar" slot="bottom">
          {nav.map((item) => <IonTabButton key={item.path} tab={item.label.toLowerCase()} href={item.path}><IonIcon icon={item.icon} /><IonLabel>{item.label}</IonLabel></IonTabButton>)}
        </IonTabBar>
      </IonTabs>
    </div>
  </IonSplitPane>;
}
