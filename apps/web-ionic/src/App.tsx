import { useEffect } from "react";
import { IonApp, setupIonicReact } from "@ionic/react";
import { IonReactRouter } from "@ionic/react-router";
import { Route, Routes } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext";
import { RequireAuth } from "./components/AppLayout";
import { ErrorBoundary } from "./components/ErrorBoundary";
import "@ionic/react/css/core.css";
import "@ionic/react/css/normalize.css";
import "@ionic/react/css/structure.css";
import "@ionic/react/css/typography.css";
import "./styles/ionic.css";

// Ionic owns authenticated navigation, route/overlay lifecycle, safe areas,
// and every signed-in screen's scroll container. The public Login doorway is
// intentionally a separate, lighter bundle (PublicApp.tsx).
setupIonicReact({ mode: "md", swipeBackEnabled: true });

function ReturnToPublicDoorway() {
  useEffect(() => {
    window.location.replace("/login");
  }, []);
  return <div className="fullscreen-note" role="status">Returning to sign in…</div>;
}

export function App() {
  return (
    <IonApp>
      <IonReactRouter>
        <ErrorBoundary>
          <AuthProvider>
            <Routes>
              <Route path="/login" element={<ReturnToPublicDoorway />} />
              <Route path="/*" element={<RequireAuth />} />
            </Routes>
          </AuthProvider>
        </ErrorBoundary>
      </IonReactRouter>
    </IonApp>
  );
}
