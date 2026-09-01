import { useState } from "react";
import { IonButton, IonContent, IonHeader, IonInput, IonPage, IonText, IonTitle, IonToolbar } from "@ionic/react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";
import { Wordmark } from "../components/Wordmark";

export function LoginPage() {
  const navigate = useNavigate();
  const { login, loading, error, fixtureMode } = useAuth();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    try {
      const me = await login({ username: username.trim(), password });
      navigate(me.consent.timetable ? "/home" : "/consent", { replace: true });
    } catch { /* context exposes the user-facing error */ }
  }

  return <IonPage data-scroll-model="FIT"><IonHeader><IonToolbar><IonTitle><Wordmark /></IonTitle></IonToolbar></IonHeader><IonContent className="screen-content login-content" scrollY={false}><main className="fit-screen" id="main-view"><div className="login-copy"><p className="eyebrow">School, with more context</p><h1 className="page-title">Continue with your school account</h1><p>It creates or reconnects your HOney account. There is no separate signup.</p></div><form className="login-form" onSubmit={(event) => void submit(event)}><IonInput fill="outline" label="School username" labelPlacement="stacked" value={username} onIonInput={(event) => setUsername(event.detail.value ?? "")} autocomplete="username" required /><IonInput fill="outline" label="School password" labelPlacement="stacked" value={password} onIonInput={(event) => setPassword(event.detail.value ?? "")} type="password" autocomplete="current-password" required />{error && <IonText color="danger"><p role="alert">{error}</p></IonText>}<IonButton expand="block" type="submit" disabled={loading || (!fixtureMode && (!username.trim() || !password))}>{loading ? "Connecting…" : "Continue"}</IonButton>{fixtureMode && <IonButton expand="block" fill="outline" type="button" onClick={() => { setUsername("fixture"); setPassword("fixture"); }}>Fill fixture account</IonButton>}</form><p className="fine login-fine">Your school password is used to establish the school connection. Importing your timetable is a separate decision on the next screen.</p></main></IonContent></IonPage>;
}
