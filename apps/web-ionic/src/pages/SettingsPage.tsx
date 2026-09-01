import { useState } from "react";
import { IonAlert, IonContent, IonHeader, IonIcon, IonItem, IonLabel, IonList, IonNote, IonPage, IonTitle, IonToast, IonToolbar } from "@ionic/react";
import { chevronForward, cloudOfflineOutline, lockClosedOutline, logOutOutline, openOutline, personOutline, refreshOutline, shieldCheckmarkOutline } from "ionicons/icons";
import { useNavigate } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { useAuth } from "../auth/AuthContext";

export function SettingsPage() {
  const navigate = useNavigate();
  const { me, logout, refresh } = useAuth();
  const [busy, setBusy] = useState(false);
  const [deleteAlert, setDeleteAlert] = useState<"data" | "account" | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  async function sync() { setBusy(true); try { const { result } = await api.syncSeamless(); setToast(result.status === "ok" ? `Synced ${result.lessons} lessons.` : "The school portal needs to reconnect."); await refresh(); } catch (cause) { setToast(describeApiError(cause)); } finally { setBusy(false); } }
  async function destructive() { if (!deleteAlert) return; setBusy(true); try { if (deleteAlert === "data") { await api.deleteImportedData(); await refresh(); setToast("Imported timetable data deleted."); } else { await api.deleteAccount(); await logout(); navigate("/login", { replace: true }); } } catch (cause) { setToast(describeApiError(cause)); } finally { setBusy(false); setDeleteAlert(null); } }

  return <IonPage data-scroll-model="COMPACT_OVERFLOW"><IonHeader><IonToolbar><IonTitle>Settings</IonTitle></IonToolbar></IonHeader><IonContent className="screen-content"><div className="screen-inner settings-page">
    <section><h1 className="page-title">Account</h1><IonList lines="full"><IonItem><IonIcon slot="start" icon={personOutline} /><IonLabel><h2>{me?.displayName}</h2><p>HOney ID {me?.honeyId}</p></IonLabel></IonItem><IonItem button onClick={() => void logout().then(() => navigate("/login", { replace: true }))}><IonIcon slot="start" icon={logOutOutline} /><IonLabel>Sign out</IonLabel></IonItem></IonList></section>
    <section><h2 className="section-title">School connection</h2><IonList lines="full"><IonItem><IonIcon slot="start" icon={me?.connection.connected ? shieldCheckmarkOutline : cloudOfflineOutline} /><IonLabel><h2>{me?.connection.connected ? "Connected" : "Needs attention"}</h2><p>HOney and School Portal sessions remain independent.</p></IonLabel><IonNote slot="end">{me?.connection.portalTokenValid ? "Current" : "Expired"}</IonNote></IonItem><IonItem button disabled={busy} onClick={() => void sync()}><IonIcon slot="start" icon={refreshOutline} /><IonLabel>Sync timetable</IonLabel></IonItem><IonItem button href="https://www.huayaopudong.com/student/notification" target="_blank"><IonIcon slot="start" icon={openOutline} /><IonLabel>Open School Portal</IonLabel></IonItem><IonItem button routerLink="/access"><IonLabel>Access on Web</IonLabel><IonIcon slot="end" icon={chevronForward} /></IonItem></IonList></section>
    <section><h2 className="section-title">Experiences privacy</h2><IonList lines="full"><IonItem button routerLink="/privacy"><IonIcon slot="start" icon={lockClosedOutline} /><IonLabel><h2>How publication works</h2><p>Stored author separation, device control keys, and moderation processing.</p></IonLabel><IonIcon slot="end" icon={chevronForward} /></IonItem><IonItem button routerLink="/experiences/why"><IonLabel>Why this space exists</IonLabel><IonIcon slot="end" icon={chevronForward} /></IonItem></IonList></section>
    <section><h2 className="section-title">Imported data</h2><IonList lines="full"><IonItem><IonLabel><h2>Timetable import</h2><p>{me?.consent.timetable ? "Allowed" : "Not allowed"}</p></IonLabel></IonItem><IonItem button onClick={() => setDeleteAlert("data")}><IonLabel color="danger">Delete imported timetable data</IonLabel></IonItem><IonItem button onClick={() => setDeleteAlert("account")}><IonLabel color="danger">Delete HOney account</IonLabel></IonItem></IonList></section>
  </div></IonContent><IonAlert isOpen={deleteAlert !== null} onDidDismiss={() => setDeleteAlert(null)} header={deleteAlert === "account" ? "Delete your HOney account?" : "Delete imported timetable data?"} message={deleteAlert === "account" ? "This removes the account and its imported data. Private notes on this device are separate." : "Your account remains. Home, Timetable, History, and some Experiences eligibility will lose their imported context."} buttons={[{ text: "Cancel", role: "cancel" }, { text: "Delete", role: "destructive", handler: () => void destructive() }]} /><IonToast isOpen={toast !== null} message={toast ?? ""} duration={2600} onDidDismiss={() => setToast(null)} /></IonPage>;
}
