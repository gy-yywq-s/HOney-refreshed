// Login — "one calm doorway" (legacy port-map). Step 1 is a single school-account
// action under the serif wordmark. Step 2 is a SEPARATE, active import-consent
// choice (audit §3.2): signing in and copying school data are different decisions,
// and nothing is preselected.

import { useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";
import { SchoolLoginForm } from "../components/SchoolLoginForm";

type Phase = "signin" | "consent";

export function LoginPage() {
  const navigate = useNavigate();
  const { refreshMe } = useAuth();
  const [phase, setPhase] = useState<Phase>("signin");

  // A returning, already-signed-in visitor skips straight in. (During the
  // consent step a session exists too, so only guard the sign-in phase.)
  if (phase === "signin" && api.hasSession()) return <Navigate to="/home" replace />;

  return (
    <main className="login">
      <div className="login__doorway">
        <div className="login__mark" aria-hidden="true">
          HO
        </div>
        <h1 className="login__wordmark">HOney</h1>

        {phase === "signin" ? (
          <>
            <p className="login__tagline text-3">Sign in with your school account.</p>
            <div className="login__fields">
              <SchoolLoginForm
                mode="login"
                onSuccess={async () => {
                  await refreshMe();
                  // Import consent is asked once, as an active choice; a returning
                  // account that already granted it goes straight in (iOS parity).
                  const me = await api.me();
                  if (me.consent.timetable) navigate("/home", { replace: true });
                  else setPhase("consent");
                }}
              />
            </div>
            <p className="text-4 login__footnote">
              There is no separate sign-up — your school account is your HOney account, created on
              first sign-in.
            </p>
          </>
        ) : (
          <ImportConsentStep onDone={() => navigate("/home", { replace: true })} />
        )}
      </div>
    </main>
  );
}

function ImportConsentStep({ onDone }: { onDone: () => void }) {
  const { refreshMe } = useAuth();
  const [busy, setBusy] = useState<"import" | "skip" | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function choose(importIt: boolean) {
    setBusy(importIt ? "import" : "skip");
    setError(null);
    try {
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
      {error && <div className="banner banner--danger">{error}</div>}
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
