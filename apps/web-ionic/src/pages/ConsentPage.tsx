import { IonButton, IonContent, IonHeader, IonIcon, IonPage, IonTitle, IonToolbar } from "@ionic/react";
import { calendarOutline, peopleOutline, timeOutline } from "ionicons/icons";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

export function ConsentPage() {
  const navigate = useNavigate();
  const { grantConsent } = useAuth();
  const [busy, setBusy] = useState(false);
  async function decide(value: boolean) { setBusy(true); try { await grantConsent(value); navigate("/home", { replace: true }); } finally { setBusy(false); } }
  return <IonPage data-scroll-model="FIT"><IonHeader><IonToolbar><IonTitle>Bring in your timetable?</IonTitle></IonToolbar></IonHeader><IonContent className="screen-content" scrollY={false}><div className="fit-screen consent-screen"><div><p className="eyebrow">A separate choice</p><h1 className="page-title">Let HOney copy your timetable and lesson history?</h1><p>This supports three things:</p><ul className="consent-list"><li><IonIcon icon={timeOutline} /><span><strong>Now and next</strong><small>Your school day on Home.</small></span></li><li><IonIcon icon={calendarOutline} /><span><strong>History</strong><small>Past lessons as context, not analytics.</small></span></li><li><IonIcon icon={peopleOutline} /><span><strong>Experiences eligibility</strong><small>Evidence that you share a relevant class context.</small></span></li></ul><p className="muted">Declining does not delete your HOney account. You can change this later in Settings.</p></div><div className="fit-actions"><IonButton expand="block" disabled={busy} onClick={() => void decide(true)}>Import timetable</IonButton><IonButton expand="block" fill="outline" disabled={busy} onClick={() => void decide(false)}>Not now</IonButton></div></div></IonContent></IonPage>;
}
