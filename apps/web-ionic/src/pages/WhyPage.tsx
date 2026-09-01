import { IonBackButton, IonButtons, IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from "@ionic/react";

export function WhyPage() {
  return (
    <IonPage data-scroll-model="DOCUMENT">
      <IonHeader><IonToolbar><IonButtons slot="start"><IonBackButton defaultHref="/experiences" /></IonButtons><IonTitle>Why this space exists</IonTitle></IonToolbar></IonHeader>
      <IonContent className="screen-content">
        <article className="document-inner">
          <p className="eyebrow">Experiences</p>
          <h1 className="page-title">For students, between students.</h1>
          <p>School is partly understood through what people who share it tell one another. Teachers may be discussed here, but this is not a feedback inbox addressed to them, and no post is a final judgment of a person.</p>
          <h2>Why share?</h2>
          <p>Something can be worth sharing because another student may find it useful, because it mattered to you and you want it represented, or both.</p>
          <h2>Partial, but still meaningful</h2>
          <p>People are more than one experience. Experiences still matter. Read each post as one situated account, and read more than one when the context matters.</p>
          <h2>Negative and mixed experiences belong</h2>
          <p>You do not have to make an experience positive, balanced, or perfectly explained. Specific context can help; feelings still count. Negative is allowed. Cruelty is not.</p>
          <h2>What HOney verifies</h2>
          <p>HOney checks relevant exposure where possible. It does not certify every interpretation as fact. Reactions show resonance, not truth.</p>
          <h2>What this space does not carry</h2>
          <p>If a matter reasonably needs investigation, safeguarding, discipline, or urgent action, a public peer feed is not the right institution. HOney will not publish or automatically send that text to the school; it can show appropriate channels.</p>
          <h2>How public Experiences are separated</h2>
          <p>Your school account verifies whether you can contribute. Published Experiences are stored without an author field, and the final public publish request carries no ordinary account identity. Your device may keep a private control key so you can manage a post later.</p>
          <p className="notice">The words themselves can still make someone recognisable to people who know the situation. HOney does not promise network-level anonymity.</p>
          <h2>How to read</h2>
          <ul>
            <li>Read each post as one person’s situated account.</li>
            <li>Compare more than one Experience when the context matters.</li>
            <li>Disagreement does not automatically mean fabrication.</li>
            <li>Entity pages provide context, not a final score.</li>
          </ul>
        </article>
      </IonContent>
    </IonPage>
  );
}
