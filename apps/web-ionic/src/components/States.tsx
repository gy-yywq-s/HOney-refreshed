import { IonButton, IonIcon } from "@ionic/react";
import { alertCircleOutline, refreshOutline } from "ionicons/icons";

export function LoadingState({ lines = 4, label = "Loading" }: { lines?: number; label?: string }) {
  return (
    <div className="loading-lines" role="status" aria-label={label}>
      {Array.from({ length: lines }, (_, index) => <div className="loading-line" key={index} />)}
    </div>
  );
}

export function ErrorState({ message, retry }: { message: string; retry?: () => void }) {
  return (
    <div className="empty-state" role="alert">
      <IonIcon icon={alertCircleOutline} size="large" color="danger" />
      <h2>That did not load</h2>
      <p>{message}</p>
      {retry && <IonButton fill="outline" onClick={retry}><IonIcon slot="start" icon={refreshOutline} />Try again</IonButton>}
    </div>
  );
}

export function EmptyState({ title, body, action }: { title: string; body: string; action?: React.ReactNode }) {
  return <div className="empty-state"><h2>{title}</h2><p>{body}</p>{action}</div>;
}
