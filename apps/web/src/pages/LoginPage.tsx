// Scroll model: FIT (§16.14.2) — one screen keyboard-closed; the route region absorbs keyboard height.
// Login — "one calm doorway" (legacy port-map): ONE school-account action
// under the wordmark. Signing in is the decision to bring your timetable
// along (Gary 2026-09-01) — the first import runs server-side on account
// creation; later sign-ins never import. The only option here is the
// opt-in "stay connected" credential store, unchecked by default.

import { useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { api } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { SchoolLoginForm } from "../components/SchoolLoginForm";
import { WordmarkHOney } from "../components/Wordmark";
import { portalCredentials } from "../lib/portalCredentials";

export function LoginPage() {
  const navigate = useNavigate();
  const { refreshMe } = useAuth();
  const [stayConnected, setStayConnected] = useState(false);

  // A returning, already-signed-in visitor skips straight in.
  if (api.hasSession()) return <Navigate to="/home" replace />;

  return (
    <main className="login">
      <div className="login__doorway">
        <h1 className="login__wordmark">
          <WordmarkHOney height={54} />
        </h1>

        <p className="login__tagline text-3">Sign in with your school account.</p>
        <div className="login__fields">
          <SchoolLoginForm
            mode="login"
            onSuccess={(_result, creds) => {
              // Opt-in only: remember the school login on this device so a
              // routine portal expiry reconnects silently (mirrors iOS).
              if (stayConnected && creds) void portalCredentials.authorize(creds);
              navigate("/home", { replace: true });
              void refreshMe();
            }}
          />
        </div>
        <label className="stay-connected">
          <input
            type="checkbox"
            checked={stayConnected}
            onChange={(e) => setStayConnected(e.target.checked)}
          />
          <span>
            <strong>Stay connected on this device.</strong> Keeps you signed in to the school
            portal so HOney can re-sync on its own when the portal times out. Your login is
            encrypted and kept only on this device. Turn it off any time in Settings.
          </span>
        </label>
        <p className="text-4 login__footnote">
          There is no separate sign-up — your school account is your HOney account, created on
          first sign-in. Your timetable comes along with it.
        </p>
      </div>
    </main>
  );
}
