import { IonBackButton, IonButton, IonButtons, IonContent, IonHeader, IonIcon, IonPage, IonTitle, IonToolbar } from "@ionic/react";
import { addOutline } from "ionicons/icons";
import { useParams } from "react-router-dom";
import { api } from "../api/client";
import { ErrorState, LoadingState } from "../components/States";
import { useLoadable } from "../hooks/useLoadable";
import { formatShortDay, formatTime } from "../lib/format";

export function LessonDetailPage() {
  const { id = "" } = useParams();
  const result = useLoadable(async () => (await api.history({ limit: 100 })).lessons.find((lesson) => lesson.id === id) ?? null, id);
  return <IonPage data-scroll-model="COMPACT_OVERFLOW"><IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/history" /></IonButtons><IonTitle>Past lesson</IonTitle></IonToolbar></IonHeader><IonContent className="screen-content"><div className="screen-inner lesson-detail">{result.loading && <LoadingState />}{result.error && <ErrorState message={result.error} retry={() => void result.refresh()} />}{result.data === null && !result.loading && !result.error && <ErrorState message="That lesson is no longer in the imported history." />}{result.data && <><p className="eyebrow">{formatShortDay(new Date(result.data.startsAt))} · {formatTime(result.data.startsAt)}–{formatTime(result.data.endsAt)}</p><h1 className="page-title">{result.data.subjectName}</h1><p>{result.data.teacherName}{result.data.roomName ? ` · ${result.data.roomName}` : ""}</p>{result.data.topicName && <p className="muted">{result.data.topicName}</p>}<hr className="rule" /><IonButton expand="block" routerLink={`/experiences/compose?lesson=${encodeURIComponent(result.data.id)}`}><IonIcon slot="start" icon={addOutline} />Share what this was like</IonButton>{result.data.teacherId && <IonButton expand="block" fill="outline" routerLink={`/experiences/teacher/${encodeURIComponent(result.data.teacherId)}`}>Teacher Experiences</IonButton>}{result.data.courseId && <IonButton expand="block" fill="outline" routerLink={`/experiences/course/${encodeURIComponent(result.data.courseId)}`}>Course Experiences</IonButton>}</>}</div></IonContent></IonPage>;
}
