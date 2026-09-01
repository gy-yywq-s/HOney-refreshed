import { IonButton, IonContent, IonPage } from "@ionic/react";
export function NotFoundPage() { return <IonPage><IonContent><div className="fit-screen"><div><p className="eyebrow">404</p><h1 className="page-title">This page is not here.</h1><p>The route may have moved, or the link may be incomplete.</p><IonButton routerLink="/home">Go home</IonButton></div></div></IonContent></IonPage>; }
