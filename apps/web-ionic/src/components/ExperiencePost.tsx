import { useMemo, useState } from "react";
import {
  IonActionSheet,
  IonButton,
  IonIcon,
  IonToast,
} from "@ionic/react";
import { addOutline, ellipsisHorizontal, thumbsDownOutline, thumbsUpOutline } from "ionicons/icons";
import type { EntitySummary, PublicExperience, ReportCategory } from "@honey/shared/api";
import { Link, useNavigate } from "react-router-dom";
import { api, ApiError } from "../api/client";
import { relativeBucket } from "../lib/format";

const provenance: Record<string, string> = {
  verified_lesson: "from a class you’ve taken",
  verified_retrospective: "from someone who has taken this over time",
  verified_member: "from a student here",
};

const reportButtons: { text: string; value: ReportCategory }[] = [
  { text: "Private or identifying information", value: "doxxing" },
  { text: "Targeted abuse or threat", value: "slur" },
  { text: "About a student", value: "targets_student" },
  { text: "Serious matter that should not be public", value: "serious_allegation" },
  { text: "Rumor, spam, or not an experience", value: "not_experience" },
  { text: "Another community-rule problem", value: "other_rule" },
];

function context(exp: PublicExperience): EntitySummary[] {
  const result: EntitySummary[] = [];
  const seen = new Set<string>();
  const add = (item: EntitySummary | undefined) => {
    if (!item?.name || seen.has(`${item.type}:${item.id}`)) return;
    seen.add(`${item.type}:${item.id}`);
    result.push(item);
  };
  add(exp.contexts?.find((item) => item.type === "course"));
  add(exp.contexts?.find((item) => item.type === "teacher"));
  if (exp.primary?.type !== "lesson") add(exp.primary);
  add(exp.contexts?.find((item) => item.type === "room"));
  return result;
}

function path(item: EntitySummary): string | null {
  if (item.type === "lesson") return null;
  return `/experiences/${item.type}/${encodeURIComponent(item.id)}`;
}

export function ExperiencePost({ experience }: { experience: PublicExperience }) {
  const navigate = useNavigate();
  const [reaction, setReaction] = useState<1 | -1 | 0>(experience.myReaction ?? 0);
  const [counts, setCounts] = useState(experience.reactions);
  const [busy, setBusy] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [actionsOpen, setActionsOpen] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const parts = useMemo(() => context(experience), [experience]);
  const body = experience.body ?? "";
  const shouldClamp = body.length > 620 && !expanded;
  const visibleBody = shouldClamp ? `${body.slice(0, 620).replace(/\s+\S*$/, "")}…` : body;

  async function react(value: 1 | -1) {
    if (busy) return;
    const previous = reaction;
    const next = value === reaction ? 0 : value;
    setReaction(next);
    setBusy(true);
    try {
      const result = await api.reactToExperience(experience.id, next);
      setReaction(result.value);
      setCounts(result.reactions);
    } catch (cause) {
      setReaction(previous);
      const message = cause instanceof ApiError && cause.code === "not_eligible"
        ? "Reactions are for students with relevant verified exposure."
        : "That reaction was not saved. Try again.";
      setToast(message);
    } finally { setBusy(false); }
  }

  async function report(category: ReportCategory) {
    try {
      await api.reportExperience(experience.id, category);
      setToast("Report received. Disagreement alone is not treated as a report.");
    } catch { setToast("That report was not sent. Try again."); }
  }

  return (
    <article className="experience-post">
      <div className="experience-context">
        {parts.map((item, index) => {
          const href = path(item);
          return <span key={`${item.type}:${item.id}`}>{index > 0 && " · "}{href ? <Link to={href}>{item.name}</Link> : item.name}</span>;
        })}
      </div>
      <div className="experience-provenance">{provenance[experience.provenance]}{experience.publishedDay !== null ? ` · ${relativeBucket(experience.publishedDay)}` : ""}</div>
      {experience.rating !== null && <div className="food-rating" aria-label={`${experience.rating} out of 5 stars`}>{"★".repeat(experience.rating)}{"☆".repeat(5 - experience.rating)}</div>}
      <p className="experience-body">{visibleBody}</p>
      {shouldClamp && <button className="text-action" onClick={() => setExpanded(true)}>Read more</button>}
      <div className="experience-actions">
        <IonButton fill="clear" size="small" aria-label="Matches my experience" aria-pressed={reaction === 1} disabled={busy} onClick={() => void react(1)}>
          <IonIcon slot="start" icon={thumbsUpOutline} />{counts ? counts.likes : "Match"}
        </IonButton>
        <IonButton fill="clear" size="small" aria-label="Does not match my experience" aria-pressed={reaction === -1} disabled={busy} onClick={() => void react(-1)}>
          <IonIcon slot="start" icon={thumbsDownOutline} />{counts ? counts.dislikes : "Different"}
        </IonButton>
        <IonButton fill="clear" size="small" routerLink={`/experiences/compose?entity=${encodeURIComponent(experience.entity_key)}`} aria-label="Add your experience">
          <IonIcon slot="icon-only" icon={addOutline} />
        </IonButton>
        <IonButton fill="clear" size="small" aria-label="More options" onClick={() => setActionsOpen(true)}><IonIcon slot="icon-only" icon={ellipsisHorizontal} /></IonButton>
      </div>
      <IonActionSheet
        isOpen={actionsOpen}
        onDidDismiss={() => setActionsOpen(false)}
        header="Experience options"
        buttons={[
          { text: "Add your experience", handler: () => navigate(`/experiences/compose?entity=${encodeURIComponent(experience.entity_key)}`) },
          { text: "Report a rule problem", role: "destructive", handler: () => setReportOpen(true) },
          { text: "Cancel", role: "cancel" },
        ]}
      />
      <IonActionSheet
        isOpen={reportOpen}
        onDidDismiss={() => setReportOpen(false)}
        header="Report a rule problem"
        subHeader="Disagreement is a reaction, not a report. No free text is collected."
        buttons={[...reportButtons.map((item) => ({ text: item.text, handler: () => void report(item.value) })), { text: "Cancel", role: "cancel" }]}
      />
      <IonToast isOpen={toast !== null} message={toast ?? ""} duration={2800} onDidDismiss={() => setToast(null)} />
    </article>
  );
}
