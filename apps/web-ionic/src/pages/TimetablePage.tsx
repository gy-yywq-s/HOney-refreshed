import { useMemo, useState } from "react";
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonModal,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import { addOutline, calendarOutline, chevronBack, chevronForward } from "ionicons/icons";
import type { Lesson } from "@honey/shared/api";
import { api } from "../api/client";
import { EmptyState, ErrorState, LoadingState } from "../components/States";
import { useLoadable } from "../hooks/useLoadable";
import { formatShortDay, formatTime } from "../lib/format";

function iso(date: Date): string { return date.toISOString().slice(0, 10); }

export function TimetablePage() {
  const [date, setDate] = useState(() => new Date());
  const [selected, setSelected] = useState<Lesson | null>(null);
  const result = useLoadable(() => api.timetable(iso(date)), iso(date));
  const now = Date.now();

  function move(days: number) { setDate((current) => new Date(current.getTime() + days * 86_400_000)); }

  return (
    <IonPage data-scroll-model="FRAMED_SCROLL">
      <IonHeader><IonToolbar><IonTitle>Timetable</IonTitle><IonButtons slot="end"><IonButton routerLink="/history"><IonIcon slot="start" icon={calendarOutline} />History</IonButton></IonButtons></IonToolbar><div className="date-nav"><IonButton fill="clear" aria-label="Previous day" onClick={() => move(-1)}><IonIcon slot="icon-only" icon={chevronBack} /></IonButton><div><strong>{formatShortDay(date)}</strong>{iso(date) === iso(new Date()) && <span>Today</span>}</div><IonButton fill="clear" aria-label="Next day" onClick={() => move(1)}><IonIcon slot="icon-only" icon={chevronForward} /></IonButton></div></IonHeader>
      <IonContent className="screen-content" id="main-view">
        <IonRefresher slot="fixed" onIonRefresh={(event) => void result.refresh().finally(() => event.detail.complete())}><IonRefresherContent /></IonRefresher>
        <main className="screen-inner timetable-scroll" data-scroll-owner="day-timeline">
          {result.loading && <LoadingState lines={7} />}
          {result.error && <ErrorState message={result.error} retry={() => void result.refresh()} />}
          {result.data?.lessons.length === 0 && <EmptyState title="Nothing scheduled" body="There are no imported lessons on this day." />}
          {result.data && <IonList className="timeline" lines="none">{result.data.lessons.map((lesson) => <LessonRow key={lesson.id} lesson={lesson} now={now} onOpen={() => setSelected(lesson)} />)}</IonList>}
        </main>
      </IonContent>
      <LessonModal lesson={selected} onDismiss={() => setSelected(null)} />
    </IonPage>
  );
}

function LessonRow({ lesson, now, onOpen }: { lesson: Lesson; now: number; onOpen(): void }) {
  const state = now >= lesson.startsAt && now < lesson.endsAt ? "now" : now < lesson.startsAt ? "upcoming" : "past";
  return <IonItem button detail={false} className={`timeline-row timeline-row--${state}`} onClick={onOpen}><div className="timeline-time" slot="start"><strong>{formatTime(lesson.startsAt)}</strong><span>{formatTime(lesson.endsAt)}</span></div><IonLabel className="ion-text-wrap"><h2>{lesson.subjectName}</h2><p>{lesson.teacherName}{lesson.roomName ? ` · ${lesson.roomName}` : ""}</p>{lesson.topicName && <p className="secondary-compact">{lesson.topicName}</p>}</IonLabel>{state === "now" && <span slot="end" className="now-marker">Now</span>}</IonItem>;
}

function LessonModal({ lesson, onDismiss }: { lesson: Lesson | null; onDismiss(): void }) {
  const links = useMemo(() => lesson ? [lesson.teacherId && `/experiences/teacher/${encodeURIComponent(lesson.teacherId)}`, lesson.courseId && `/experiences/course/${encodeURIComponent(lesson.courseId)}`].filter(Boolean) as string[] : [], [lesson]);
  return <IonModal isOpen={lesson !== null} onDidDismiss={onDismiss} initialBreakpoint={0.58} breakpoints={[0, 0.58, 0.9]}><IonHeader><IonToolbar><IonButtons slot="start"><IonButton onClick={onDismiss}>Close</IonButton></IonButtons><IonTitle>Lesson</IonTitle></IonToolbar></IonHeader><IonContent>{lesson && <div className="document-inner"><p className="eyebrow">{formatTime(lesson.startsAt)}–{formatTime(lesson.endsAt)}</p><h1 className="page-title">{lesson.subjectName}</h1><p>{lesson.teacherName}{lesson.roomName ? ` · ${lesson.roomName}` : ""}</p>{lesson.topicName && <p className="muted">{lesson.topicName}</p>}<div className="modal-actions"><IonButton expand="block" routerLink={`/experiences/compose?lesson=${encodeURIComponent(lesson.id)}`} onClick={onDismiss}><IonIcon slot="start" icon={addOutline} />Share what this was like</IonButton>{links[0] && <IonButton expand="block" fill="outline" routerLink={links[0]} onClick={onDismiss}>See teacher Experiences</IonButton>}{links[1] && <IonButton expand="block" fill="outline" routerLink={links[1]} onClick={onDismiss}>See course Experiences</IonButton>}</div></div>}</IonContent></IonModal>;
}
