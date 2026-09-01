import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonTitle,
  IonToolbar,
} from "@ionic/react";
import { arrowForward, personCircleOutline } from "ionicons/icons";
import type { FeedPage, NextLessonResponse } from "@honey/shared/api";
import { Link } from "react-router-dom";
import { api } from "../api/client";
import { LoadingState, ErrorState } from "../components/States";
import { Wordmark } from "../components/Wordmark";
import { useAuth } from "../auth/AuthContext";
import { useLoadable } from "../hooks/useLoadable";
import { formatDay, formatTime } from "../lib/format";

export function HomePage() {
  const { me } = useAuth();
  const dashboard = useLoadable(async () => {
    const [lesson, voices] = await Promise.all([api.nextLesson(), api.feedPage({ scope: "my_classes", limit: 3 })]);
    return { lesson, voices };
  }, "home");

  return (
    <IonPage data-scroll-model="COMPACT_OVERFLOW">
      <IonHeader>
        <IonToolbar>
          <IonTitle className="home-wordmark"><Wordmark /></IonTitle>
          <IonButtons slot="end"><IonButton routerLink="/settings" aria-label="Account and settings"><IonIcon slot="icon-only" icon={personCircleOutline} /></IonButton></IonButtons>
        </IonToolbar>
      </IonHeader>
      <IonContent className="screen-content home-content">
        <div className="screen-inner home-composition">
          <header className="home-greeting">
            <h1 className="page-title">Hi, {me?.displayName ?? "there"}</h1>
            <p>{formatDay(new Date())}</p>
          </header>
          {dashboard.loading && <LoadingState lines={5} label="Loading your school day" />}
          {dashboard.error && <ErrorState message={dashboard.error} retry={() => void dashboard.refresh()} />}
          {dashboard.data && <HomeLoaded lesson={dashboard.data.lesson} voices={dashboard.data.voices} />}
        </div>
      </IonContent>
    </IonPage>
  );
}

function HomeLoaded({ lesson, voices }: { lesson: NextLessonResponse; voices: FeedPage }) {
  const next = lesson.nextLesson;
  return (
    <>
      <section className="lesson-focus surface" aria-labelledby="now-next-label">
        <p className="eyebrow" id="now-next-label">{next?.temporalState === "now" ? "Now" : "Next"}</p>
        {next ? <>
          <div className="lesson-focus-row">
            <div>
              <h2>{next.subjectName}</h2>
              <p>{formatTime(next.startsAt)}–{formatTime(next.endsAt)}{next.teacherName ? ` · ${next.teacherName}` : ""}{next.roomName ? ` · ${next.roomName}` : ""}</p>
            </div>
            <strong>{next.temporalState === "now" ? "In progress" : `In ${next.minutesUntilStart} min`}</strong>
          </div>
          {next.topicName && <p className="lesson-topic secondary-compact">{next.topicName}</p>}
        </> : <><h2>Nothing else is scheduled today.</h2><p className="muted">Your next school day will appear here after the timetable syncs.</p></>}
        <Link className="inline-route" to="/timetable">Open timetable <IonIcon icon={arrowForward} /></Link>
      </section>

      <section className="home-voices" aria-labelledby="home-voices-title">
        <div className="section-row"><h2 className="section-title" id="home-voices-title">From your classes</h2><Link to="/experiences">See all</Link></div>
        {voices.items.slice(0, 2).map((voice, index) => <Link className={`voice-preview ${index > 0 ? "secondary-preview" : ""}`} to="/experiences" key={voice.id}>
          <span className="voice-preview-body">{voice.body}</span>
          <span className="fine">{voice.contexts?.filter((item) => item.type === "course" || item.type === "teacher").map((item) => item.name).join(" · ")}</span>
        </Link>)}
      </section>

      <div className="home-actions">
        <IonButton routerLink="/experiences/compose">Share something</IonButton>
        <a className="portal-row" href="https://www.huayaopudong.com/student/notification" target="_blank" rel="noreferrer">
          <span><strong>School Portal</strong><small>Open OASIS in a new tab</small></span><IonIcon icon={arrowForward} />
        </a>
      </div>
    </>
  );
}
