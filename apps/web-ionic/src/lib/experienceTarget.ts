import type { ExperienceEligibilityInput } from "@honey/shared/api";

const LESSON_PREFIX = "lesson:";

export function targetFromSearch(search: string): string {
  const query = new URLSearchParams(search);
  const lessonId = query.get("lesson")?.trim();
  if (lessonId) return `${LESSON_PREFIX}${lessonId}`;
  return query.get("entity")?.trim() ?? "";
}

export function targetInput(target: string): ExperienceEligibilityInput {
  if (target.startsWith(LESSON_PREFIX)) {
    return { lessonId: target.slice(LESSON_PREFIX.length) };
  }
  return { entityKey: target };
}

export function lessonIdFromTarget(target: string): string | null {
  return target.startsWith(LESSON_PREFIX) ? target.slice(LESSON_PREFIX.length) : null;
}
