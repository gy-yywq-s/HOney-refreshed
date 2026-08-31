import { useState } from "react";
import type { FormEvent } from "react";
import { api, describeApiError } from "../api/client";
import type { LoginResponse } from "../api/types";

interface SchoolLoginFormProps {
  /** "login" shows the consent checkbox; "reconnect" is credentials-only. */
  mode: "login" | "reconnect";
  onSuccess: (result: LoginResponse) => void;
}

export function SchoolLoginForm({ mode, onSuccess }: SchoolLoginFormProps) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [consent, setConsent] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const input =
        mode === "login"
          ? { username, password, consentTimetable: consent }
          : { username, password };
      onSuccess(await api.login(input));
    } catch (err) {
      setError(describeApiError(err));
      setBusy(false);
    }
  }

  return (
    <form onSubmit={(e) => void submit(e)}>
      {error && <div className="banner banner--danger">{error}</div>}
      <div className="field">
        <label className="field__label" htmlFor="school-username">
          School username
        </label>
        <input
          id="school-username"
          className="input"
          autoComplete="username"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          required
        />
      </div>
      <div className="field">
        <label className="field__label" htmlFor="school-password">
          Password
        </label>
        <input
          id="school-password"
          className="input"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
      </div>
      {mode === "login" && (
        <label className="checkbox">
          <input type="checkbox" checked={consent} onChange={(e) => setConsent(e.target.checked)} />
          <span>Import my timetable</span>
        </label>
      )}
      <button className="btn btn--primary btn--block" type="submit" disabled={busy}>
        {busy ? "Signing in…" : mode === "login" ? "Continue with school account" : "Reconnect"}
      </button>
    </form>
  );
}
