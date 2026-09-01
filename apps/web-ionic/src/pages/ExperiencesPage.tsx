import { useCallback, useEffect, useRef, useState } from "react";
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonSegment,
  IonSegmentButton,
  IonTitle,
  IonToolbar,
  useIonViewDidEnter,
  useIonViewWillLeave,
} from "@ionic/react";
import { addOutline, bookmarkOutline, searchOutline } from "ionicons/icons";
import type { FeedScope, PublicExperience } from "@honey/shared/api";
import { Link } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { ExperiencePost } from "../components/ExperiencePost";
import { EmptyState, ErrorState, LoadingState } from "../components/States";

interface Snapshot { items: PublicExperience[]; cursor: string | null; offset: number; }
const snapshots = new Map<FeedScope, Snapshot>();

export function ExperiencesPage() {
  const [scope, setScope] = useState<FeedScope>("my_classes");
  const restored = snapshots.get(scope);
  const [items, setItems] = useState<PublicExperience[]>(restored?.items ?? []);
  const [cursor, setCursor] = useState<string | null>(restored?.cursor ?? null);
  const [loading, setLoading] = useState(!restored);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const content = useRef<HTMLIonContentElement>(null);

  const load = useCallback(async (append = false) => {
    if (append) setLoadingMore(true);
    else setLoading(true);
    setError(null);
    try {
      const page = await api.feedPage(
        append && cursor ? { scope, cursor, limit: 12 } : { scope, limit: 12 },
      );
      setItems((current) => append ? [...current, ...page.items.filter((item) => !current.some((existing) => existing.id === item.id))] : page.items);
      setCursor(page.nextCursor);
    } catch (cause) { setError(describeApiError(cause)); }
    finally { setLoading(false); setLoadingMore(false); }
  }, [scope, cursor]);

  useEffect(() => {
    const existing = snapshots.get(scope);
    if (existing) {
      setItems(existing.items); setCursor(existing.cursor); setError(null); setLoading(false);
      requestAnimationFrame(() => void content.current?.scrollToPoint(0, existing.offset));
    } else { setItems([]); setCursor(null); void load(false); }
  }, [scope]);

  useIonViewDidEnter(() => {
    const existing = snapshots.get(scope);
    if (existing) requestAnimationFrame(() => void content.current?.scrollToPoint(0, existing.offset));
  });
  useIonViewWillLeave(() => {
    void content.current?.getScrollElement().then((element) => snapshots.set(scope, { items, cursor, offset: element.scrollTop }));
  });

  return (
    <IonPage data-scroll-model="FRAMED_SCROLL">
      <IonHeader>
        <IonToolbar><IonTitle role="heading" aria-level={1}>Experiences</IonTitle><IonButtons slot="end">
          <IonButton routerLink="/experiences/explore" aria-label="Explore"><IonIcon slot="icon-only" icon={searchOutline} /></IonButton>
          <IonButton routerLink="/experiences/mine" aria-label="Your notes and posts"><IonIcon slot="icon-only" icon={bookmarkOutline} /></IonButton>
          <IonButton routerLink="/experiences/compose" aria-label="Share an experience"><IonIcon slot="icon-only" icon={addOutline} /></IonButton>
        </IonButtons></IonToolbar>
        <div className="community-line"><strong>For students, between students</strong> — not a teacher feedback channel. <Link to="/experiences/why">Why this space exists</Link></div>
        <IonSegment value={scope} onIonChange={(event) => setScope(event.detail.value as FeedScope)}>
          <IonSegmentButton value="my_classes">Your classes</IonSegmentButton>
          <IonSegmentButton value="school">Around school</IonSegmentButton>
        </IonSegment>
      </IonHeader>
      <IonContent ref={content} className="screen-content feed-scroll" scrollEvents>
        <IonRefresher slot="fixed" onIonRefresh={(event) => void load(false).finally(() => event.detail.complete())}><IonRefresherContent /></IonRefresher>
        <main className="feed-column" id="main-view" data-scroll-owner="experiences-feed">
          {loading && <LoadingState lines={8} label="Loading Experiences" />}
          {error && <ErrorState message={error} retry={() => void load(false)} />}
          {!loading && !error && items.length === 0 && <EmptyState title={scope === "my_classes" ? "Nothing from your classes yet" : "Nothing has been shared yet"} body={scope === "my_classes" ? "When someone shares an Experience connected to a class you’ve taken, it will appear here." : "A short thought is enough to begin."} action={<IonButton routerLink="/experiences/compose">Share the first one</IonButton>} />}
          {items.map((item, index) => <div key={item.id}>
            <ExperiencePost experience={item} />
            {(index + 1) % 7 === 0 && <aside className="share-invitation"><strong>Anything from school you want to put into words?</strong><IonButton fill="outline" size="small" routerLink="/experiences/compose">Share an experience</IonButton></aside>}
          </div>)}
          {cursor && <div className="feed-more"><IonButton fill="clear" disabled={loadingMore} onClick={() => void load(true)}>{loadingMore ? "Loading…" : "Read more"}</IonButton></div>}
        </main>
      </IonContent>
    </IonPage>
  );
}
