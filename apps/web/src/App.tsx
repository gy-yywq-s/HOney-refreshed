import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext";
import { RequireAuth } from "./components/AppLayout";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { Suspense, lazy } from "react";

// Admin console: code-split — students never download it (design-is r1).
const DashPage = lazy(() => import("./pages/DashPage").then((m) => ({ default: m.DashPage })));
import { AccessPage } from "./pages/AccessPage";
import { AccessHowPage } from "./pages/AccessHowPage";
import { ExperiencesComposePage } from "./pages/experiences/ComposePage";
import { ExperienceEntityPage } from "./pages/experiences/EntityPage";
import { ExperiencesFeedPage } from "./pages/experiences/FeedPage";
import { ExperiencesExplorePage } from "./pages/experiences/ExplorePage";
import { ExperiencesWhyPage } from "./pages/experiences/WhyPage";
import { ExperiencesMinePage } from "./pages/experiences/MinePage";
import { NoticesPage } from "./pages/NoticesPage";
import { CampusCardPage, SchoolRecordPage, WeekendStayPage } from "./pages/settings/SchoolRecordsPages";
import { HistoryPage } from "./pages/HistoryPage";
import { HomePage } from "./pages/HomePage";
import { LoginPage } from "./pages/LoginPage";
import { NotFoundPage } from "./pages/NotFoundPage";
import { SettingsPage } from "./pages/SettingsPage";
import { PostControlsPage } from "./pages/settings/PostControlsPage";
import { PostControlsHowPage } from "./pages/settings/PostControlsHowPage";
import { RecoveryWordsPage } from "./pages/settings/RecoveryWordsPage";
import { PairDevicePage } from "./pages/settings/PairDevicePage";
import { RotateRootPage } from "./pages/settings/RotateRootPage";
import { TimetablePage } from "./pages/TimetablePage";

export function App() {
  return (
    <BrowserRouter>
      <ErrorBoundary>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<RequireAuth />}>
              <Route path="/home" element={<HomePage />} />
              <Route path="/timetable" element={<TimetablePage />} />
              <Route path="/history" element={<HistoryPage />} />
              <Route path="/notices" element={<NoticesPage />} />
              <Route path="/notices/:id" element={<NoticesPage />} />
              {/* Deep-link reserved by spec §6.3; renders the list for now. */}
              <Route path="/history/lesson/:id" element={<HistoryPage />} />
              <Route path="/experiences" element={<ExperiencesFeedPage />} />
              <Route path="/experiences/explore" element={<ExperiencesExplorePage />} />
              <Route path="/experiences/why" element={<ExperiencesWhyPage />} />
              <Route path="/experiences/mine" element={<ExperiencesMinePage />} />
              <Route path="/experiences/compose" element={<ExperiencesComposePage />} />
              <Route
                path="/experiences/teacher/:id"
                element={<ExperienceEntityPage kind="teacher" />}
              />
              <Route
                path="/experiences/course/:id"
                element={<ExperienceEntityPage kind="course" />}
              />
              <Route path="/experiences/room/:id" element={<ExperienceEntityPage kind="room" />} />
              <Route path="/experiences/dish/:id" element={<ExperienceEntityPage kind="dish" />} />
              {/* Legacy aliases from the placeholder era — bookmarks keep working. */}
              <Route path="/experiences/place/:id" element={<ExperienceEntityPage kind="room" />} />
              <Route path="/experiences/food/:id" element={<ExperienceEntityPage kind="dish" />} />
              <Route path="/access" element={<AccessPage />} />
              <Route path="/access/how" element={<AccessHowPage />} />
              <Route path="/settings" element={<SettingsPage />} />
              <Route path="/settings/card" element={<CampusCardPage />} />
              <Route path="/settings/weekend" element={<WeekendStayPage />} />
              <Route path="/settings/record" element={<SchoolRecordPage />} />
              <Route path="/settings/post-controls" element={<PostControlsPage />} />
              <Route path="/settings/post-controls/how" element={<PostControlsHowPage />} />
              <Route path="/settings/post-controls/recovery-words" element={<RecoveryWordsPage />} />
              <Route path="/settings/post-controls/pair" element={<PairDevicePage />} />
              <Route path="/settings/post-controls/replace-root" element={<RotateRootPage />} />
              <Route path="/settings/:section" element={<SettingsPage />} />
              <Route
                path="/dash"
                element={
                  <Suspense fallback={<div className="fullscreen-note">Loading…</div>}>
                    <DashPage />
                  </Suspense>
                }
              />
              {/* A wrong address stays inside the shell: nav + skip link. */}
              <Route path="*" element={<NotFoundPage />} />
            </Route>
            <Route path="/" element={<Navigate to="/home" replace />} />
          </Routes>
        </AuthProvider>
      </ErrorBoundary>
    </BrowserRouter>
  );
}
