import { useMemo, useState } from "react";
import {
  IonBackButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonNote,
  IonPage,
  IonSearchbar,
  IonSegment,
  IonSegmentButton,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import { restaurantOutline, schoolOutline, storefrontOutline, walkOutline } from "ionicons/icons";
import type { EntityRef, EntityType } from "@honey/shared/api";
import { api } from "../api/client";
import { ErrorState, LoadingState } from "../components/States";
import { useLoadable } from "../hooks/useLoadable";

const sections: { type: EntityType; label: string; icon: string }[] = [
  { type: "teacher", label: "Teachers", icon: schoolOutline },
  { type: "course", label: "Courses", icon: walkOutline },
  { type: "room", label: "Places", icon: storefrontOutline },
  { type: "dish", label: "Food", icon: restaurantOutline },
];

export function ExplorePage() {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<EntityType | "all">("all");
  const result = useLoadable(() => api.entities(), "all-entities");
  const filtered = useMemo(() => {
    const needle = query.trim().toLowerCase();
    return (result.data?.entities ?? []).filter((item) => (category === "all" || item.type === category) && (!needle || item.name.toLowerCase().includes(needle)));
  }, [category, query, result.data]);

  return (
    <IonPage data-scroll-model="FRAMED_EDITOR">
      <IonHeader>
        <IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/experiences" /></IonButtons><IonTitle>Explore</IonTitle></IonToolbar>
        <IonSearchbar className="honey-search explore-control" value={query} onIonInput={(event) => setQuery(event.detail.value ?? "")} placeholder="Find teachers, courses, places, or food" debounce={100} />
        <IonSegment className="explore-control" scrollable value={category} onIonChange={(event) => setCategory(event.detail.value as EntityType | "all")}>
          <IonSegmentButton value="all">All</IonSegmentButton>
          {sections.map((section) => <IonSegmentButton key={section.type} value={section.type}>{section.label}</IonSegmentButton>)}
        </IonSegment>
      </IonHeader>
      <IonContent className="screen-content">
        <div className="screen-inner explore-content" data-scroll-owner="explore-results">
          <header className="explore-intro"><h1 className="page-title">Find something at school</h1><p>Search narrows the complete directory; it does not search students’ words.</p></header>
          {result.loading && <LoadingState lines={7} />}
          {result.error && <ErrorState message={result.error} retry={() => void result.refresh()} />}
          {!result.loading && !result.error && sections.filter((section) => category === "all" || category === section.type).map((section) => {
            const items = filtered.filter((item) => item.type === section.type).sort((a, b) => a.name.localeCompare(b.name));
            return <EntitySection key={section.type} {...section} items={items} query={query} />;
          })}
        </div>
      </IonContent>
    </IonPage>
  );
}

function EntitySection({ type, label, icon, items, query }: { type: EntityType; label: string; icon: string; items: EntityRef[]; query: string }) {
  return <section className="entity-section" aria-labelledby={`section-${type}`}>
    <div className="section-row"><h2 className="section-title" id={`section-${type}`}><IonIcon icon={icon} /> {label}</h2><IonNote>{items.length}</IonNote></div>
    {items.length === 0 ? <p className="muted">{query ? "Nothing by that name." : "Nothing here yet."}</p> : <IonList lines="full">
      {items.map((item) => <IonItem key={item.entity_key} button detail routerLink={`/experiences/${item.type}/${encodeURIComponent(item.entity_key.split(":")[1] ?? item.entity_key)}`}><IonLabel>{item.name}</IonLabel></IonItem>)}
    </IonList>}
  </section>;
}
