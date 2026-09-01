import { useRef, useState } from "react";
import { IonButton, IonContent, IonHeader, IonInput, IonPage, IonText, IonTitle, IonToolbar } from "@ionic/react";
import { Navigate, useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { Wordmark } from "../components/Wordmark";

export function LoginPage() {
  const navigate = useNavigate();
  const { me, login, loading, error, fixtureMode } = useAuth();
  const usernameInput = useRef<HTMLIonInputElement>(null);
  const passwordInput = useRef<HTMLIonInputElement>(null);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [fieldError, setFieldError] = useState<string | null>(null);

  if (me) return <Navigate to="/home" replace />;

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    // Password managers can write directly to IonInput's native input without
    // emitting ionInput. Read the rendered controls at submit time so an
    // autofilled form is never mistaken for an empty one.
    const usernameElement = await usernameInput.current?.getInputElement();
    const passwordElement = await passwordInput.current?.getInputElement();
    const submittedUsername = (usernameElement?.value ?? username).trim();
    const submittedPassword = passwordElement?.value ?? password;
    if (!submittedUsername || !submittedPassword) {
      setFieldError("Enter your school username and password.");
      return;
    }
    setFieldError(null);
    try {
      const me = await login({ username: submittedUsername, password: submittedPassword });
      navigate(me.consent.timetable ? "/home" : "/consent", { replace: true });
    } catch { /* context exposes the user-facing error */ }
  }

  return <IonPage data-scroll-model="FIT"><IonHeader><IonToolbar><IonTitle><Wordmark /></IonTitle></IonToolbar></IonHeader><IonContent className="screen-content login-content" scrollY={false}><main className="fit-screen" id="main-view"><div className="login-copy"><p className="eyebrow">School, with more context</p><h1 className="page-title">Continue with your school account</h1><p>It creates or reconnects your HOney account. There is no separate signup.</p></div><form className="login-form" onSubmit={(event) => void submit(event)}><IonInput ref={usernameInput} id="school-username" name="username" fill="outline" label="School username" labelPlacement="stacked" value={username} onIonInput={(event) => { setUsername(event.detail.value ?? ""); setFieldError(null); }} autocomplete="username" autocapitalize="none" spellcheck={false} required /><IonInput ref={passwordInput} id="school-password" name="password" fill="outline" label="School password" labelPlacement="stacked" value={password} onIonInput={(event) => { setPassword(event.detail.value ?? ""); setFieldError(null); }} type="password" autocomplete="current-password" required />{(fieldError || error) && <IonText color="danger"><p role="alert">{fieldError || error}</p></IonText>}<IonButton expand="block" type="submit" disabled={loading}>{loading ? "Connecting…" : "Continue"}</IonButton>{fixtureMode && <IonButton expand="block" fill="outline" type="button" onClick={() => { setUsername("fixture"); setPassword("fixture"); setFieldError(null); }}>Fill fixture account</IonButton>}</form><p className="fine login-fine">Your school password is used to establish the school connection. Importing your timetable is a separate decision on the next screen.</p></main></IonContent></IonPage>;
}
