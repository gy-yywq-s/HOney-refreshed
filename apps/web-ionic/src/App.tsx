import { IonApp } from "@ionic/react";
import { IonReactRouter } from "@ionic/react-router";
import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext";
import { RequireAuth } from "./components/AppLayout";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { IonicRoutePage } from "./components/IonicRoutePage";
import { LoginPage } from "./pages/LoginPage";

export function App() {
  return (
    <IonApp>
      <IonReactRouter>
        <ErrorBoundary>
          <AuthProvider>
            <Routes>
              <Route
                path="/login"
                element={
                  <IonicRoutePage model="FIT" refreshable={false} publicScreen>
                    <LoginPage />
                  </IonicRoutePage>
                }
              />
              <Route path="/*" element={<RequireAuth />} />
              <Route path="*" element={<Navigate to="/home" replace />} />
            </Routes>
          </AuthProvider>
        </ErrorBoundary>
      </IonReactRouter>
    </IonApp>
  );
}
