import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider } from "./auth/AuthContext";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { LoginPage } from "./pages/LoginPage";

/** A deliberately small public entry: one landmark, one task, no Ionic shell. */
export function PublicApp() {
  return (
    <BrowserRouter>
      <ErrorBoundary>
        <AuthProvider>
          <Routes>
            <Route
              path="/login"
              element={
                <main className="public-route" data-scroll-owner>
                  <LoginPage onAuthenticated={() => window.location.replace("/home")} />
                </main>
              }
            />
            <Route path="*" element={<Navigate to="/login" replace />} />
          </Routes>
        </AuthProvider>
      </ErrorBoundary>
    </BrowserRouter>
  );
}
