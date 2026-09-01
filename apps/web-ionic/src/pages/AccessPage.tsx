import { IonBackButton, IonButtons, IonContent, IonHeader, IonIcon, IonPage, IonTitle, IonToolbar } from "@ionic/react";
import { phonePortraitOutline, shieldOutline } from "ionicons/icons";

export function AccessPage() {
  return <IonPage data-scroll-model="FIT"><IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/settings" /></IonButtons><IonTitle>Access</IonTitle></IonToolbar></IonHeader><IonContent className="screen-content" scrollY={false}><main className="fit-screen access-screen" id="main-view"><div className="access-mark"><IonIcon icon={shieldOutline} /></div><div><p className="eyebrow">Web capability</p><h1 className="page-title">Access is not available in this browser.</h1><p>The school system does not currently allow a safe direct browser connection. HOney will not relay a physical gate action through its backend or pretend that a fixture is live.</p><p className="muted"><IonIcon icon={phonePortraitOutline} /> Use the iOS app for direct-to-school Access where it is supported.</p></div></main></IonContent></IonPage>;
}
