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
import { AccessPage } from "./pages/AccessPage";
import { ComposePage } from "./pages/ComposePage";
import { ConsentPage } from "./pages/ConsentPage";
import { EntityPage } from "./pages/EntityPage";
import { ExperiencesPage } from "./pages/ExperiencesPage";
import { ExplorePage } from "./pages/ExplorePage";
import { HistoryPage } from "./pages/HistoryPage";
import { HomePage } from "./pages/HomePage";
import { LessonDetailPage } from "./pages/LessonDetailPage";
import { LoginPage } from "./pages/LoginPage";
import { MinePage } from "./pages/MinePage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { PrivacyPage } from "./pages/PrivacyPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TimetablePage } from "./pages/TimetablePage";
import { WhyPage } from "./pages/WhyPage";

export function App() {
  return <IonApp><IonReactRouter><AuthProvider><a className="skip-link" href="#main-view">Skip to content</a><Routes>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/consent" element={<ConsentPage />} />
    <Route path="/*" element={<AuthenticatedApp />} />
  </Routes></AuthProvider></IonReactRouter></IonApp>;
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
