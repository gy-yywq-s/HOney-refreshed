// Experiences is an M2 feature: these are typed placeholders that keep the
// deep-link routes (spec §6.3) live so the rest of the app can link to them.

import { Link, useParams, useSearchParams } from "react-router-dom";

type EntityKind = "teacher" | "course" | "place" | "food";

const ENTITY_TITLES: Record<EntityKind, string> = {
  teacher: "Teacher experiences",
  course: "Course experiences",
  place: "Place experiences",
  food: "Food experiences",
};

function ComingSoon({ note }: { note?: string | undefined }) {
  return (
    <div className="card placeholder">
      <h2 className="section-title">Experiences arrive with the community backend</h2>
      <p className="muted">
        Anonymous, moderated notes about lessons, teachers, places and food are part of the next
        milestone. This page is already routable so nothing you bookmark today breaks later.
      </p>
      {note && <p className="caption">{note}</p>}
    </div>
  );
}

export function ExperiencesPage() {
  return (
    <div>
      <h1 className="page-title">Experiences</h1>
      <ComingSoon />
      <div className="card-actions">
        <Link className="btn btn--primary" to="/experiences/compose">
          Share an experience
        </Link>
      </div>
    </div>
  );
}

export function ExperiencesComposePage() {
  const [searchParams] = useSearchParams();
  const lessonId = searchParams.get("lessonId");

  return (
    <div>
      <h1 className="page-title">Share an experience</h1>
      <ComingSoon note={lessonId ? `Prepared for lesson ${lessonId}.` : undefined} />
      <div className="card-actions">
        <Link className="btn btn--ghost" to="/history?select=1">
          Pick a lesson from History
        </Link>
      </div>
    </div>
  );
}

export function ExperienceEntityPage({ kind }: { kind: EntityKind }) {
  const { id } = useParams();

  return (
    <div>
      <h1 className="page-title">{ENTITY_TITLES[kind]}</h1>
      <ComingSoon note={id ? `This page will show experiences for ${kind} ${id}.` : undefined} />
    </div>
  );
}
