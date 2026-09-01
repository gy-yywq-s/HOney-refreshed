import { useEffect, useState } from "react";
import {
  IonAlert,
  IonBackButton,
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonItem,
  IonLabel,
  IonList,
  IonNote,
  IonPage,
  IonSegment,
  IonSegmentButton,
  IonTitle,
  IonToast,
  IonToolbar,
} from "@ionic/react";
import type { MyExperience } from "@honey/shared/api";
import { useNavigate } from "react-router-dom";
import { api, describeApiError } from "../api/client";
import { EmptyState, LoadingState } from "../components/States";
import { localRecords, type PrivateNote } from "../lib/localRecords";

export function MinePage() {
  const navigate = useNavigate();
  const [section, setSection] = useState<"private" | "shared">("private");
  const [notes, setNotes] = useState<PrivateNote[]>(() => localRecords.notes());
  const [shared, setShared] = useState<MyExperience[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<{ kind: "note" | "post"; id: string } | null>(null);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    void api.myExperiences(localRecords.ownershipKeys()).then((result) => setShared(result.experiences)).catch((cause) => setError(describeApiError(cause))).finally(() => setLoading(false));
  }, []);

  async function remove() {
    if (!confirm) return;
    if (confirm.kind === "note") {
      localRecords.removeNote(confirm.id);
      setNotes(localRecords.notes());
      setToast("Private note removed from this device.");
    } else {
      const record = localRecords.ownershipRecords().find((item) => item.experienceId === confirm.id);
      if (!record) { setToast("This device no longer has the control key for that post."); return; }
      try {
        await api.revokeExperience(record.key);
        localRecords.removeOwnershipKey(confirm.id);
        setShared((items) => items.map((item) => item.id === confirm.id ? { ...item, status: "revoked" } : item));
        setToast("The public Experience was revoked.");
      } catch (cause) { setToast(describeApiError(cause)); }
    }
    setConfirm(null);
  }

  function resume(note: PrivateNote) {
    try {
      localRecords.saveDraft({ target: note.target, targetLabel: note.targetLabel, body: note.body, savedAt: Date.now() });
      localRecords.removeNote(note.id);
      setNotes(localRecords.notes());
      navigate("/experiences/compose");
    } catch {
      setToast("This device could not restore that private draft.");
    }
  }

  return (
    <IonPage data-scroll-model="FRAMED_SCROLL">
      <IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/experiences" /></IonButtons><IonTitle>Your notes & posts</IonTitle></IonToolbar><IonSegment value={section} onIonChange={(event) => setSection(event.detail.value as "private" | "shared")}><IonSegmentButton value="private">Private notes</IonSegmentButton><IonSegmentButton value="shared">Shared</IonSegmentButton></IonSegment></IonHeader>
      <IonContent className="screen-content">
        <div className="screen-inner" data-scroll-owner="notes-and-posts">
          {section === "private" ? <PrivateNotes notes={notes} onRemove={(id) => setConfirm({ kind: "note", id })} onResume={resume} /> : loading ? <LoadingState /> : error ? <div className="notice error-notice">{error}</div> : <SharedPosts posts={shared} onRevoke={(id) => setConfirm({ kind: "post", id })} />}
        </div>
      </IonContent>
      <IonAlert isOpen={confirm !== null} onDidDismiss={() => setConfirm(null)} header={confirm?.kind === "post" ? "Revoke this public Experience?" : "Remove this private note?"} message={confirm?.kind === "post" ? "It will leave the public feed. This device will also forget its control key." : "This only removes the note from this device."} buttons={[{ text: "Cancel", role: "cancel" }, { text: confirm?.kind === "post" ? "Revoke" : "Remove", role: "destructive", handler: () => void remove() }]} />
      <IonToast isOpen={toast !== null} message={toast ?? ""} duration={2600} onDidDismiss={() => setToast(null)} />
    </IonPage>
  );
}

function PrivateNotes({ notes, onRemove, onResume }: { notes: PrivateNote[]; onRemove(id: string): void; onResume(note: PrivateNote): void }) {
  if (notes.length === 0) return <EmptyState title="No private notes yet" body="Keeping something for yourself is a first-class choice, not a failed attempt to publish." action={<IonButton routerLink="/experiences/compose">Write a private note</IonButton>} />;
  return <IonList lines="full">{notes.map((note) => <IonItem key={note.id}><IonLabel className="ion-text-wrap"><p className="eyebrow">{note.state === "cooldown" ? "Cooling period · kept privately" : note.targetLabel}</p><h2>{note.body}</h2>{note.state === "cooldown" && <p>{note.targetLabel} · Resume when you want to decide again.</p>}<p>{new Date(note.savedAt).toLocaleString("en-GB")}</p></IonLabel><div slot="end" className="note-actions">{note.state === "cooldown" && <IonButton fill="outline" onClick={() => onResume(note)}>Continue draft</IonButton>}<IonButton fill="clear" color="danger" onClick={() => onRemove(note.id)}>Remove</IonButton></div></IonItem>)}</IonList>;
}

function SharedPosts({ posts, onRevoke }: { posts: MyExperience[]; onRevoke(id: string): void }) {
  if (posts.length === 0) return <EmptyState title="No shared Experiences on this device" body="When you share, this device keeps a private control key so you can manage the post later." />;
  return <IonList lines="full">{posts.map((post) => <IonItem key={post.id}><IonLabel className="ion-text-wrap"><h2>{post.body}</h2><p>{post.status === "published" ? "Shared publicly" : post.status}</p></IonLabel><IonNote slot="end">{post.status === "published" && <IonButton fill="clear" color="danger" onClick={() => onRevoke(post.id)}>Revoke</IonButton>}</IonNote></IonItem>)}</IonList>;
}
