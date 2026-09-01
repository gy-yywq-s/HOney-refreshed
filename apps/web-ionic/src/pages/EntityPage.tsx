import {
  IonBackButton,
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import { addOutline } from "ionicons/icons";
import { useParams } from "react-router-dom";
import type { EntityType } from "@honey/shared/api";
import { api } from "../api/client";
import { ExperiencePost } from "../components/ExperiencePost";
import { EmptyState, ErrorState, LoadingState } from "../components/States";
import { useLoadable } from "../hooks/useLoadable";

const labels: Record<EntityType, string> = { teacher: "Teacher", course: "Course", room: "Place", dish: "Food" };

export function EntityPage({ type }: { type: EntityType }) {
  const { id = "" } = useParams();
  const entityKey = `${type}:${id}`;
  const result = useLoadable(async () => {
    const [entityResponse, page] = await Promise.all([api.entities(type), api.feedPage({ scope: "school", entityKey, limit: 20 })]);
    return { entity: entityResponse.entities.find((item) => item.entity_key === entityKey), page };
  }, entityKey);
  const name = result.data?.entity?.name ?? labels[type];

  return (
    <IonPage data-scroll-model="FRAMED_SCROLL">
      <IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/experiences/explore" /></IonButtons><IonTitle>{name}</IonTitle><IonButtons slot="end"><IonButton routerLink={`/experiences/compose?entity=${encodeURIComponent(entityKey)}`} aria-label={`Share your experience of ${name}`}><IonIcon slot="icon-only" icon={addOutline} /></IonButton></IonButtons></IonToolbar></IonHeader>
      <IonContent className="screen-content" id="main-view">
        <main className="feed-column entity-feed" data-scroll-owner="entity-feed">
          <header className="entity-head">
            <p className="eyebrow">{labels[type]}</p>
            <h1 className="page-title">{name}</h1>
            <p>{type === "teacher" ? `What students have experienced in classes with ${name}. ` : type === "course" ? "Experiences of this course across lessons and teachers. " : "Experiences shared from this context. "}<strong>No single Experience is the whole picture.</strong></p>
            <IonButton routerLink={`/experiences/compose?entity=${encodeURIComponent(entityKey)}`}><IonIcon slot="start" icon={addOutline} />Share your experience</IonButton>
          </header>
          {result.loading && <LoadingState lines={7} />}
          {result.error && <ErrorState message={result.error} retry={() => void result.refresh()} />}
          {result.data && result.data.page.items.length === 0 && <EmptyState title="Nothing has been shared here yet" body="A short thought can be enough to begin a fuller picture." />}
          {result.data?.page.items.map((item) => <ExperiencePost key={item.id} experience={item} />)}
        </main>
      </IonContent>
    </IonPage>
  );
}
