// Scroll model: FIT (§16.14.2) — one screen keyboard-closed; the route region absorbs keyboard height.
// Login — "one calm doorway" (legacy port-map): ONE school-account action
// under the wordmark. Signing in is the decision to bring your timetable
// along (Gary 2026-09-01) — the first import runs server-side on account
// creation; later sign-ins never import. No options here (Gary 2026-09-02):
// HOney keeps the school login on this device by default so portal
// time-outs reconnect on their own; Settings › School connection is where
// that is turned off.

import { useEffect } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { SchoolLoginForm } from "../components/SchoolLoginForm";
import { WordmarkHOney } from "../components/Wordmark";
import { portalCredentials } from "../lib/portalCredentials";

export function LoginPage() {
  useEffect(() => {
    document.title = "Sign in · HOney";
  }, []);
  const navigate = useNavigate();
  const { refreshMe } = useAuth();

  // A returning, already-signed-in visitor skips straight in.
  if (api.hasSession()) return <Navigate to="/home" replace />;

  return (
    <main className="login" id="main">
      <a className="skip-link" href="#school-username">
        Skip to sign-in
      </a>
      <div className="login__doorway">
        <h1 className="login__wordmark">
          <WordmarkHOney height={54} />
        </h1>

        <p className="login__tagline">Your school day, without the portal friction.</p>
        <p className="text-3 login__support">Use your school account. HOney creates no separate password.</p>
        <div className="login__fields">
          <SchoolLoginForm
            mode="login"
            onSuccess={(_result, creds) => {
              // Kept on this device unless turned off in Settings, so a
              // routine portal expiry reconnects silently (mirrors iOS).
              if (creds && portalCredentials.wanted()) void portalCredentials.authorize(creds);
              navigate("/home", { replace: true });
              void refreshMe();
            }}
          />
        </div>
        <p className="text-4 login__footnote">
          There is no separate sign-up — your school account is your HOney account, created on
          first sign-in. Your timetable and history come along with it, and again whenever you sync
          — Sync now in Settings, or pulling the timetable down to sync. HOney keeps your school
          login on this device so portal time-outs reconnect on their own; turn that off in
          Settings › School connection.
        </p>
      </div>
    </main>
  );
}
