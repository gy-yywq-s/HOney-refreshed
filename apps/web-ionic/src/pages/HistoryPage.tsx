import { useMemo, useRef, useState } from "react";
import { IonBackButton, IonButtons, IonContent, IonHeader, IonItem, IonLabel, IonList, IonPage, IonSearchbar, IonTitle, IonToolbar, useIonViewDidEnter, useIonViewWillLeave } from "@ionic/react";
import type { Lesson } from "@honey/shared/api";
import { api } from "../api/client";
import { EmptyState, ErrorState, LoadingState } from "../components/States";
import { useLoadable } from "../hooks/useLoadable";
import { formatShortDay, formatTime } from "../lib/format";

let historyOffset = 0;

export function HistoryPage() {
  const [query, setQuery] = useState("");
  const content = useRef<HTMLIonContentElement>(null);
  const result = useLoadable(() => api.history({ limit: 80, order: "desc" }), "history");
  const groups = useMemo(() => groupLessons((result.data?.lessons ?? []).filter((lesson) => !query || `${lesson.subjectName} ${lesson.teacherName ?? ""}`.toLowerCase().includes(query.toLowerCase()))), [query, result.data]);
  useIonViewDidEnter(() => {
    requestAnimationFrame(() => void content.current?.scrollToPoint(0, historyOffset));
  });
  useIonViewWillLeave(() => { void content.current?.getScrollElement().then((element) => { historyOffset = element.scrollTop; }); });

  return <IonPage data-scroll-model="FRAMED_SCROLL"><IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/timetable" /></IonButtons><IonTitle>History</IonTitle></IonToolbar><IonSearchbar className="honey-search" value={query} onIonInput={(event) => setQuery(event.detail.value ?? "")} placeholder="Find a teacher or course" debounce={100} /></IonHeader><IonContent ref={content} className="screen-content"><div className="screen-inner" data-scroll-owner="history-list">{result.loading && <LoadingState lines={8} />}{result.error && <ErrorState message={result.error} retry={() => void result.refresh()} />}{result.data && groups.size === 0 && <EmptyState title="No matching lessons" body="Try another teacher or course name." />}{[...groups.entries()].map(([date, lessons]) => <section className="history-group" key={date}><h2>{date}</h2><IonList lines="full">{lessons.map((lesson) => <IonItem button detail routerLink={`/history/lesson/${encodeURIComponent(lesson.id)}`} key={lesson.id}><IonLabel><h3>{lesson.subjectName}</h3><p>{lesson.teacherName}{lesson.roomName ? ` · ${lesson.roomName}` : ""}</p></IonLabel><span slot="end" className="fine nowrap">{formatTime(lesson.startsAt)}</span></IonItem>)}</IonList></section>)}</div></IonContent></IonPage>;
}

function groupLessons(lessons: Lesson[]): Map<string, Lesson[]> {
  const groups = new Map<string, Lesson[]>();
  for (const lesson of lessons) {
    const key = formatShortDay(new Date(lesson.startsAt));
    const list = groups.get(key) ?? [];
    list.push(lesson); groups.set(key, list);
  }
  return groups;
}
