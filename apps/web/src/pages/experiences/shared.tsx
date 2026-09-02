// Shared building blocks for the Experiences surfaces: check-reason copy,
// star display / input, name resolution, and the "from your classes" hook.
// (The stream's post card lives in features/experiences/ExperiencePost.)

import { useMemo } from "react";
import { api, ApiError } from "../../api/client";
import type { DirectoryResponse, EntityRef } from "../../api/types";
import { useApi } from "../../lib/useApi";

// ---------------------------------------------------------------------------
// Labels & paths
// ---------------------------------------------------------------------------

/** Spec §7.3: provenance is labeled honestly — never "verified use" for dishes. */
const PROVENANCE_LABELS: Record<string, string> = {
  verified_lesson: "Verified lesson experience",
  verified_retrospective: "From someone who has taken this over time",
  verified_member: "Verified school member",
};

export function provenanceLabel(provenance: string): string {
  return PROVENANCE_LABELS[provenance] ?? "Verified school member";
}

/** Route for an entity page; the URL carries the id part of the entity_key. */
export function entityPath(entity: Pick<EntityRef, "entity_key" | "type">): string {
  const id = entity.entity_key.slice(entity.entity_key.indexOf(":") + 1);
  return `/experiences/${entity.type}/${encodeURIComponent(id)}`;
}

/** Friendly copy for every submit 422 the backend can return. */
/**
 * Gate-prefixed check reason codes → the ONE boundary sentence the user sees
 * (review v3 §10.4). Unknown/internal codes render nothing — detector details
 * are never a UI surface.
 */
const CHECK_REASON_COPY: Record<string, string> = {
  "standing:hearsay": "It describes something you heard rather than your own experience.",
  "expression:targeted_profanity":
    "Part of the wording targets a person rather than describing the experience.",
  "expression:targets_student":
    "It evaluates or identifies another student — students aren't public subjects here.",
  "expression:privacy_invasion":
    "It includes private details that could identify or expose someone.",
  "expression:lexical:identifying_information":
    "It includes contact or identifying information. Remove it — the experience can still be told.",
  "expression:injection_attempt":
    "Part of the text reads as instructions to the system rather than an experience.",
  "expression:uncertain":
    "HOney could not confidently understand part of this wording. Say it more directly.",
  "timing:high_arousal":
    "This can still be your experience. Publishing it can wait until you'd share it the same way tomorrow.",
  "composition:low_information":
    "A little context about what led you here can help another student — optional.",
  rating_not_allowed_for_entity: "Star ratings only exist for canteen dishes.",
};

export function describeCheckReasons(reasons: string[] | undefined): string[] {
  return (reasons ?? []).map((r) => CHECK_REASON_COPY[r]).filter((r): r is string => !!r);
}

export const SUBMIT_ERROR_COPY: Record<string, string> = {
  publications_disabled:
    "Publishing is paused for everyone right now. You can still save this privately and publish once posting reopens.",
  body_invalid: "The text is empty or longer than 5000 characters.",
  rating_invalid: "Stars are whole numbers from 1 to 5.",
  lesson_not_yours:
    "That lesson isn't in your imported history, so this account can't review it. Pick a lesson from your own History.",
  entity_unknown: "This entry is no longer listed.",
  entity_frozen: "New experiences for this entry are paused by the moderators right now.",
  standalone_closed: "Reviews for this entry are closed right now.",
  not_invited: "This entry is invite-only, and this account hasn't been invited to review it.",
  no_verified_exposure:
    "You can review teachers and rooms your imported timetable shows you've actually had — nothing in your history matches this entry.",
  rating_not_allowed:
    "Stars are for dishes only, never for people, lessons or rooms. Remove the rating to continue.",
  cooldown_ticket_invalid:
    "You edited the text since the waiting period started, so the check needs to run once more. Nothing was lost.",
  already_reviewed:
    "You've already shared an experience for this. Remove it in Your notes & posts if you want to write a new one.",
};

export function describeSubmitError(err: unknown): string {
  if (err instanceof ApiError && SUBMIT_ERROR_COPY[err.code]) return SUBMIT_ERROR_COPY[err.code]!;
  if (err instanceof ApiError && err.code === "network_error") {
    return "Could not reach the HOney server. Check your connection and try again.";
  }
  return "Something went wrong submitting this. Please try again.";
}

// ---------------------------------------------------------------------------
// Stars (dishes only)
// ---------------------------------------------------------------------------

export function Stars({ value }: { value: number }) {
  return (
    <span className="stars" role="img" aria-label={`${value} out of 5 stars`}>
      {"★★★★★".slice(0, value)}
      <span className="stars__empty">{"★★★★★".slice(value)}</span>
    </span>
  );
}

export function StarInput({
  value,
  onChange,
}: {
  value: number | null;
  onChange: (v: number | null) => void;
}) {
  return (
    <div className="star-input" role="radiogroup" aria-label="Dish rating (1 to 5 stars)">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          role="radio"
          aria-checked={value === n}
          aria-label={`${n} star${n > 1 ? "s" : ""}`}
          className={value !== null && n <= value ? "star-input__star star-input__star--on" : "star-input__star"}
          onClick={() => onChange(value === n ? null : n)}
        >
          ★
        </button>
      ))}
      {value !== null && (
        <button type="button" className="btn btn--ghost btn--small" onClick={() => onChange(null)}>
          Clear
        </button>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Name resolution (directory ids + entity registry → display names)
// ---------------------------------------------------------------------------

export interface NameMaps {
  teacher: Map<string, string>;
  course: Map<string, string>;
  room: Map<string, string>;
  /** entity_key → registry name (covers dishes and admin-imported entries). */
  entity: Map<string, string>;
}

export function buildNameMaps(
  directory: DirectoryResponse | null,
  entities: EntityRef[] | null,
): NameMaps {
  return {
    teacher: new Map(directory?.teachers.map((t) => [t.id, t.name]) ?? []),
    course: new Map(directory?.courses.map((c) => [c.id, c.name]) ?? []),
    room: new Map(directory?.rooms.map((r) => [r.id, r.name]) ?? []),
    entity: new Map(entities?.map((e) => [e.entity_key, e.name]) ?? []),
  };
}

/** One-line context ("Maths · Ms Lin · Room 204") from whatever ids resolve. */
export function useNames(enabled = true) {
  const directory = useApi(
    () => (enabled ? api.directory() : Promise.resolve(null)),
    [enabled],
    enabled ? "directory" : undefined,
  );
  const entities = useApi(
    () => (enabled ? api.entities() : Promise.resolve(null)),
    [enabled],
    enabled ? "entities" : undefined,
  );
  const names = useMemo(
    () => buildNameMaps(directory.data, entities.data?.entities ?? null),
    [directory.data, entities.data],
  );
  return {
    names,
    directory: directory.data,
    entities: entities.data?.entities ?? null,
    /** First lookup failure, so pages can show an error branch (r7). */
    error: directory.error ?? entities.error,
    loading: directory.loading || entities.loading,
    reload: () => {
      directory.reload();
      entities.reload();
    },
  };
}

// ---------------------------------------------------------------------------
// "From your classes" — a backend domain query (audit §4.2). The server knows
// the caller's verified exposure; the client no longer fetches the newest feed
// and filters it. Still chronological and unranked.
// ---------------------------------------------------------------------------

export function useFromYourClasses(limit = 100) {
  const feed = useApi(() => api.fromMyClasses({ limit }), [limit], `experiences:from-my-classes:${limit}`);
  return {
    experiences: feed.data?.experiences ?? null,
    loading: feed.loading,
    error: feed.error,
  };
}

