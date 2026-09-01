import { useEffect, useMemo, useState } from "react";
import {
  IonBackButton,
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonItem,
  IonLabel,
  IonList,
  IonListHeader,
  IonModal,
  IonPage,
  IonSearchbar,
  IonText,
  IonTextarea,
  IonTitle,
  IonToast,
  IonToolbar,
} from "@ionic/react";
import { chevronDownOutline, lockClosedOutline, paperPlaneOutline } from "ionicons/icons";
import { useLocation, useNavigate } from "react-router-dom";
import type { CheckExperienceResponse, EntityRef, Lesson } from "@honey/shared/api";
import { api, describeApiError } from "../api/client";
import { LoadingState } from "../components/States";
import { lessonIdFromTarget, targetFromSearch, targetInput } from "../lib/experienceTarget";
import { localRecords } from "../lib/localRecords";
import { formatShortDay, formatTime } from "../lib/format";

type Outcome = CheckExperienceResponse | { lane: "shared"; experienceId: string; controlKeySaved: boolean } | null;
type DraftState = "idle" | "saving" | "saved" | "failed";

export function ComposePage() {
  const location = useLocation();
  const navigate = useNavigate();
  const queryTarget = targetFromSearch(location.search);
  const draft = localRecords.draft();
  const [entities, setEntities] = useState<EntityRef[]>([]);
  const [lessons, setLessons] = useState<Lesson[]>([]);
  const [target, setTarget] = useState(queryTarget || draft?.target || "");
  const [targetLabel, setTargetLabel] = useState(draft?.targetLabel || "");
  const [body, setBody] = useState(draft?.body || "");
  const [pickerOpen, setPickerOpen] = useState(!target);
  const [pickerQuery, setPickerQuery] = useState("");
  const [loadingEntities, setLoadingEntities] = useState(true);
  const [busy, setBusy] = useState(false);
  const [outcome, setOutcome] = useState<Outcome>(null);
  const [eligibilityToken, setEligibilityToken] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [draftState, setDraftState] = useState<DraftState>(draft ? "saved" : "idle");
  const [ownershipRecovery, setOwnershipRecovery] = useState<{ experienceId: string; key: string } | null>(null);

  useEffect(() => {
    const today = new Date().toISOString().slice(0, 10);
    void Promise.all([
      api.entities(),
      api.history({ limit: 80, order: "desc" }),
      api.timetable(today),
    ]).then(([response, history, timetable]) => {
      setEntities(response.entities);
      setLessons(uniqueLessons([...timetable.lessons, ...history.lessons]));
      const selected = response.entities.find((item) => item.entity_key === target);
      if (selected) setTargetLabel(selected.name);
      const lessonId = lessonIdFromTarget(target);
      const selectedLesson = lessonId
        ? [...timetable.lessons, ...history.lessons].find((lesson) => lesson.id === lessonId)
        : null;
      if (selectedLesson) setTargetLabel(`${selectedLesson.subjectName}${selectedLesson.teacherName ? ` · ${selectedLesson.teacherName}` : ""}`);
      else if (lessonId && !targetLabel) setTargetLabel("Selected lesson");
    }).catch(() => setToast("Contexts could not be loaded. Try again.")).finally(() => setLoadingEntities(false));
  }, [target]);

  useEffect(() => {
    if (!target || !body.trim()) { setDraftState("idle"); return; }
    setDraftState("saving");
    const timer = window.setTimeout(() => {
      try {
        localRecords.saveDraft({ target, targetLabel, body, savedAt: Date.now() });
        setSaveError(null);
        setDraftState("saved");
      } catch {
        setDraftState("failed");
        setSaveError("This draft could not be saved on this device.");
      }
    }, 500);
    return () => window.clearTimeout(timer);
  }, [body, target, targetLabel]);

  const filtered = useMemo(() => {
    const needle = pickerQuery.toLowerCase();
    return entities.filter((item) => !needle || item.name.toLowerCase().includes(needle));
  }, [entities, pickerQuery]);
  const filteredLessons = useMemo(() => {
    const needle = pickerQuery.trim().toLowerCase();
    return lessons.filter((lesson) => !needle || `${lesson.subjectName} ${lesson.teacherName ?? ""} ${lesson.roomName ?? ""}`.toLowerCase().includes(needle));
  }, [lessons, pickerQuery]);

  function keepPrivate(state: "private" | "cooldown" = "private") {
    if (!body.trim() || !target) return;
    try {
      localRecords.saveNote({ id: crypto.randomUUID(), target, targetLabel, body: body.trim(), savedAt: Date.now(), state });
      localRecords.clearDraft();
      setToast(state === "cooldown" ? "Kept privately until you decide again." : "Kept privately on this device.");
      window.setTimeout(() => navigate("/experiences/mine", { replace: true }), 600);
    } catch { setSaveError("This note could not be saved on this device."); }
  }

  async function check() {
    if (!target || body.trim().length < 10 || busy) return;
    setBusy(true); setOutcome(null);
    try {
      const input = targetInput(target);
      const eligible = await api.experienceEligibility(input);
      setEligibilityToken(eligible.eligibilityToken);
      const result = await api.checkExperience({ ...input, body: body.trim() });
      setOutcome(result);
      if (result.lane === "publish") await publish(result.pass, eligible.eligibilityToken);
    } catch (cause) { setToast(describeApiError(cause)); }
    finally { setBusy(false); }
  }

  async function publish(pass = outcome && "pass" in outcome ? outcome.pass : undefined, token = eligibilityToken ?? undefined) {
    if (!pass || !token) return;
    setBusy(true);
    try {
      const result = await api.publishExperience({ eligibilityToken: token, pass, body: body.trim() });
      let controlKeySaved = false;
      try {
        localRecords.addOwnershipKey(result.experienceId, result.ownershipKey);
        controlKeySaved = true;
        setOwnershipRecovery(null);
      } catch {
        setOwnershipRecovery({ experienceId: result.experienceId, key: result.ownershipKey });
      }
      try { localRecords.clearDraft(); } catch { /* publication truth takes precedence over local cleanup */ }
      setOutcome({ lane: "shared", experienceId: result.experienceId, controlKeySaved });
    } catch (cause) { setToast(describeApiError(cause)); }
    finally { setBusy(false); }
  }

  function retryOwnershipSave() {
    if (!ownershipRecovery) return;
    try {
      localRecords.addOwnershipKey(ownershipRecovery.experienceId, ownershipRecovery.key);
      setOwnershipRecovery(null);
      setOutcome((current) => current?.lane === "shared" ? { ...current, controlKeySaved: true } : current);
      setToast("Control key saved on this device.");
    } catch {
      setToast("The Experience is public, but this device still could not save its control key.");
    }
  }

  return (
    <IonPage data-scroll-model="FRAMED_EDITOR">
      <IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/experiences" /></IonButtons><IonTitle>Share an experience</IonTitle></IonToolbar></IonHeader>
      <IonContent className="screen-content compose-content" scrollY={false}>
        <div className="compose-frame">
          <button className="context-picker-button" onClick={() => setPickerOpen(true)}>
            <span><small>About</small><strong>{targetLabel || "Choose a lesson, teacher, course, place, or food"}</strong></span><IonIcon icon={chevronDownOutline} />
          </button>
          <div className="compose-prompt"><h1 className="page-title">What was it like for you?</h1><p>Specific details can help someone understand. A feeling can matter too.</p></div>
          <IonTextarea className="compose-editor" fill="outline" label="Your experience" labelPlacement="stacked" value={body} onIonInput={(event) => setBody(event.detail.value ?? "")} placeholder="Write in your own words…" counter maxlength={3000} autoGrow={false} />
          <div className="compose-status" aria-live="polite">{saveError ? <IonText color="danger">{saveError}</IonText> : draftState === "saving" ? <span>Saving draft…</span> : draftState === "saved" ? <span>Draft saved on this device</span> : <span>Your words stay here until you choose an action.</span>}</div>
          {api.fixtureMode && <details className="fixture-controls"><summary>Fixture moderation scenarios</summary><p>These markers exist only in fixture mode.</p><div><IonButton size="small" fill="outline" onClick={() => setBody("[edit] This fixture checks the wording-revision state before any later boundary.")}>Revision</IonButton><IonButton size="small" fill="outline" onClick={() => setBody("[scope] This fixture checks a serious matter that needs an institutional channel.")}>Scope</IonButton><IonButton size="small" fill="outline" onClick={() => setBody("[cooldown] This fixture checks the private timing delay after all earlier boundaries pass.")}>Timing</IonButton></div></details>}
          <div className="compose-actions">
            <IonButton fill="outline" disabled={!body.trim() || !target || busy} onClick={() => keepPrivate()}><IonIcon slot="start" icon={lockClosedOutline} />Keep this for yourself</IonButton>
            <IonButton disabled={body.trim().length < 10 || !target || busy} onClick={() => void check()}><IonIcon slot="start" icon={paperPlaneOutline} />{busy ? "Checking…" : "Share anonymously"}</IonButton>
          </div>
        </div>
      </IonContent>

      <IonModal isOpen={pickerOpen} onDidDismiss={() => setPickerOpen(false)}>
        <IonHeader><IonToolbar><IonButtons slot="start"><IonButton onClick={() => setPickerOpen(false)}>Cancel</IonButton></IonButtons><IonTitle>What is this about?</IonTitle></IonToolbar><IonSearchbar className="honey-search" value={pickerQuery} onIonInput={(event) => setPickerQuery(event.detail.value ?? "")} placeholder="Find a lesson, teacher, course, place, or food" /></IonHeader>
        <IonContent>{loadingEntities ? <div className="screen-inner"><LoadingState /></div> : <IonList className="picker-list" lines="full">
          {filteredLessons.length > 0 && <IonListHeader>Recent lessons</IonListHeader>}
          {filteredLessons.map((lesson) => <IonItem button key={`lesson:${lesson.id}`} onClick={() => { setTarget(`lesson:${lesson.id}`); setTargetLabel(lessonLabel(lesson)); setPickerOpen(false); }}><IonLabel><h2>{lessonLabel(lesson)}</h2><p>{formatShortDay(new Date(lesson.startsAt))} · {formatTime(lesson.startsAt)}{lesson.roomName ? ` · ${lesson.roomName}` : ""}</p></IonLabel></IonItem>)}
          {filtered.length > 0 && <IonListHeader>School directory</IonListHeader>}
          {filtered.map((item) => <IonItem button key={item.entity_key} onClick={() => { setTarget(item.entity_key); setTargetLabel(item.name); setPickerOpen(false); }}><IonLabel><h2>{item.name}</h2><p>{item.type === "room" ? "place" : item.type}</p></IonLabel></IonItem>)}
          {filteredLessons.length === 0 && filtered.length === 0 && <IonItem><IonLabel><h2>Nothing by that name</h2><p>Try a lesson subject, teacher, course, place, or food.</p></IonLabel></IonItem>}
        </IonList>}</IonContent>
      </IonModal>
      <OutcomeModal outcome={outcome} busy={busy} onDismiss={() => setOutcome(null)} onPublish={() => void publish()} onPrivate={() => keepPrivate(outcome?.lane === "cooldown" ? "cooldown" : "private")} onEdit={() => setOutcome(null)} onRetryControl={retryOwnershipSave} />
      <IonToast isOpen={toast !== null} message={toast ?? ""} duration={2600} onDidDismiss={() => setToast(null)} />
    </IonPage>
  );
}

function OutcomeModal({ outcome, busy, onDismiss, onPublish, onPrivate, onEdit, onRetryControl }: { outcome: Outcome; busy: boolean; onDismiss(): void; onPublish(): void; onPrivate(): void; onEdit(): void; onRetryControl(): void }) {
  if (!outcome) return null;
  const shared = outcome.lane === "shared";
  const content: Record<string, { title: string; body: string }> = {
    nudge: { title: "Would you like to add what led you to feel this way?", body: "A little context can help others understand. You can still share it as written." },
    edit_required: { title: "This version needs a change before it can be shared.", body: "Part of the wording targets a person rather than describing the experience. Adjust the wording, then check it again." },
    blocked_serious: { title: "These exact words cannot be carried here.", body: "Keep the thought privately or return to the editor and change the expression." },
    out_of_scope: { title: "This needs a different kind of channel.", body: "HOney will not publish or send this text to the school. You can keep it privately and contact an appropriate school or support channel yourself." },
    cooldown: { title: "Publishing can wait.", body: "This can still be your experience. Keep it private for now, then decide again after the cooling period." },
    failed_closed: { title: "HOney could not check this reliably.", body: "Nothing was published. Your draft remains on this device so you can try again later." },
    shared: outcome.lane === "shared" && !outcome.controlKeySaved
      ? { title: "Shared, but the control key was not saved.", body: "The Experience is already public. Until this device saves its private control key, it cannot find, manage, or revoke that post later." }
      : { title: "Shared.", body: "Your school identity is not shown with this public Experience. This device saved a private control key so you can manage it later." },
    publish: { title: "Ready to share", body: "The Experience passed the current publication boundaries." },
  };
    const copy = content[outcome.lane] ?? content.failed_closed!;
  return <IonModal isOpen onDidDismiss={onDismiss} className="outcome-modal"><IonHeader><IonToolbar><IonTitle role="heading" aria-level={1}>{copy.title}</IonTitle></IonToolbar></IonHeader><IonContent><div className="document-inner"><p>{copy.body}</p><div className="modal-actions">
    {shared ? <>{!outcome.controlKeySaved && <IonButton expand="block" onClick={onRetryControl}>Try saving the control key again</IonButton>}<IonButton expand="block" fill={outcome.controlKeySaved ? "solid" : "outline"} routerLink="/experiences" onClick={onDismiss}>Return to Experiences</IonButton></> : outcome.lane === "nudge" ? <><IonButton expand="block" disabled={busy} onClick={onEdit}>Add context</IonButton><IonButton expand="block" fill="outline" disabled={busy} onClick={onPublish}>Share as written</IonButton><IonButton expand="block" fill="clear" onClick={onPrivate}>Keep private</IonButton></> : outcome.lane === "edit_required" || outcome.lane === "blocked_serious" ? <><IonButton expand="block" onClick={onEdit}>Return to your words</IonButton><IonButton expand="block" fill="clear" onClick={onPrivate}>Keep private</IonButton></> : <><IonButton expand="block" onClick={onPrivate}>Keep private</IonButton><IonButton expand="block" fill="clear" onClick={onDismiss}>Return to your words</IonButton></>}
  </div></div></IonContent></IonModal>;
}

function uniqueLessons(lessons: Lesson[]): Lesson[] {
  return [...new Map(lessons.map((lesson) => [lesson.id, lesson])).values()].sort((a, b) => b.startsAt - a.startsAt);
}

function lessonLabel(lesson: Lesson): string {
  return `${lesson.subjectName}${lesson.teacherName ? ` · ${lesson.teacherName}` : ""}`;
}
