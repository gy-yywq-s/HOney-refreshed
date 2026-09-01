// Scroll model: FIT (§16.14.2) — one screen keyboard-closed; the route region absorbs keyboard height.
// Login — "one calm doorway" (legacy port-map). Step 1 is a single school-account
// action under the serif wordmark. Step 2 is a SEPARATE, active import-consent
// choice (audit §3.2): signing in and copying school data are different decisions,
// and nothing is preselected.

import { useRef, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { SchoolLoginForm } from "../components/SchoolLoginForm";
import { WordmarkHOney } from "../components/Wordmark";
import { portalCredentials } from "../lib/portalCredentials";

type Phase = "signin" | "consent";

export function LoginPage() {
  const navigate = useNavigate();
  const { refreshMe } = useAuth();
  const [phase, setPhase] = useState<Phase>("signin");
  // Held in memory only, for the consent step's "stay connected" opt-in.
  const credsRef = useRef<{ username: string; password: string } | null>(null);

  // A returning, already-signed-in visitor skips straight in. (During the
  // consent step a session exists too, so only guard the sign-in phase.)
  if (phase === "signin" && api.hasSession()) return <Navigate to="/home" replace />;

  return (
    <div className="login">
      <div className="login__doorway">
        <h1 className="login__wordmark">
          <WordmarkHOney height={54} />
        </h1>

        {phase === "signin" ? (
          <>
            <p className="login__tagline text-3">Sign in with your school account.</p>
            <div className="login__fields">
              <SchoolLoginForm
                mode="login"
                onSuccess={(result, creds) => {
                  credsRef.current = creds;
                  // Decide the destination SYNCHRONOUSLY from the login response.
                  // Any await before setPhase re-renders with a live session while
                  // phase is still "signin", and the guard above redirects past
                  // the consent step (review 2026-09-01, finding 3). Consent is
                  // asked once, as an active choice; a returning account that
                  // already granted it goes straight in (iOS parity).
                  if (result.consent.timetable) {
                    navigate("/home", { replace: true });
                  } else {
                    setPhase("consent");
                  }
                  void refreshMe();
                }}
              />
            </div>
            <p className="text-4 login__footnote">
              There is no separate sign-up — your school account is your HOney account, created on
              first sign-in.
            </p>
          </>
        ) : (
          <ImportConsentStep creds={credsRef.current} onDone={() => navigate("/home", { replace: true })} />
        )}
      </div>
    </div>
  );
}

function ImportConsentStep({
  creds,
  onDone,
}: {
  creds: { username: string; password: string } | null;
  onDone: () => void;
}) {
  const { refreshMe } = useAuth();
  const [busy, setBusy] = useState<"import" | "skip" | null>(null);
  const [stayConnected, setStayConnected] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function choose(importIt: boolean) {
    setBusy(importIt ? "import" : "skip");
    setError(null);
    try {
      // Opt-in only: remember the school login on this device so a routine
      // portal expiry reconnects silently (mirrors iOS). Nothing is stored
      // unless the box is checked.
      if (stayConnected && creds) await portalCredentials.authorize(creds);
      if (importIt) {
        await api.setConsent(true);
        // Initial pull, so Home has data on first render.
        await api.sync().catch(() => undefined);
      }
      await refreshMe();
      onDone();
    } catch (err) {
      setError(describeApiError(err));
      setBusy(null);
    }
  }

  return (
    <div className="login__consent">
      <p className="login__tagline">One more choice.</p>
      <p className="text-3">
        HOney can copy your timetable and lesson history from the school portal so your day and your
        History work here. Nothing is imported unless you turn it on, and you can switch it off any
        time in Settings.
      </p>
      {creds && (
        <label className="stay-connected">
          <input
            type="checkbox"
            checked={stayConnected}
            onChange={(e) => setStayConnected(e.target.checked)}
          />
          <span>
            <strong>Stay connected on this device.</strong> Keeps you signed in to the school
            portal so HOney can re-sync on its own when the portal times out — no re-typing. Your
            login is encrypted and kept only on this device (a browser is less protected than a
            phone's secure storage). Turn it off any time in Settings.
          </span>
        </label>
      )}
      {error && <div role="alert" className="banner banner--danger">{error}</div>}
      <div className="login__fields">
        <button
          className="btn btn--primary btn--block"
          disabled={busy !== null}
          onClick={() => void choose(true)}
        >
          {busy === "import" ? "Importing…" : "Import my timetable"}
        </button>
        <button
          className="btn btn--ghost btn--block"
          disabled={busy !== null}
          onClick={() => void choose(false)}
        >
          {busy === "skip" ? "One moment…" : "Not now"}
        </button>
      </div>
    </div>
  );
}
