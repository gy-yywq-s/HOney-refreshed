import { Navigate, useNavigate } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { SchoolLoginForm } from "../components/SchoolLoginForm";

export function LoginPage() {
  const navigate = useNavigate();
  const { refreshMe } = useAuth();

  if (api.hasSession()) return <Navigate to="/home" replace />;

  return (
    <main className="login">
      <div className="card login__card">
        <div className="login__brand">HOney</div>
        <p className="login__tagline muted">Sign in with your school account to get started.</p>
        <SchoolLoginForm
          mode="login"
          onSuccess={async () => {
            await refreshMe();
            navigate("/home", { replace: true });
          }}
        />
        <span className="caption login__footnote">
          There is no separate sign-up — your school account is your HOney account. The first
          sign-in creates it automatically.
        </span>
      </div>
    </main>
  );
}
