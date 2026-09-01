import { useState } from "react";
import type { FormEvent } from "react";
import { api, describeApiError } from "../api/client";
import type { LoginResponse } from "../api/types";

interface SchoolLoginFormProps {
  /** Only changes the button label; import consent is a separate, later step. */
  mode: "login" | "reconnect";
  onSuccess: (result: LoginResponse) => void;
}

export function SchoolLoginForm({ mode, onSuccess }: SchoolLoginFormProps) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      // Signing in never imports the timetable. Import is a separate, active
      // choice on the next step (audit §3.2) — the request carries no consent.
      onSuccess(await api.login({ username, password }));
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
      <button className="btn btn--primary btn--block" type="submit" disabled={busy}>
        {busy ? "Signing in…" : mode === "login" ? "Continue with school account" : "Reconnect"}
      </button>
    </form>
  );
}
