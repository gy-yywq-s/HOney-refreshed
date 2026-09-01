import type {
  CheckExperienceInput,
  CheckExperienceResponse,
  DirectoryResponse,
  EntitiesResponse,
  EntityRef,
  EntityType,
  ExperienceEligibilityInput,
  ExperienceEligibilityResponse,
  FeedPage,
  FeedParams,
  FeedScope,
  FeedUpdatesResponse,
  HistoryParams,
  HistoryResponse,
  Lesson,
  LoginInput,
  LoginResponse,
  Me,
  MyExperience,
  MyExperiencesResponse,
  NextLessonResponse,
  PublicExperience,
  PublishExperienceInput,
  PublishExperienceResponse,
  ReactResponse,
  ReportCategory,
  SyncResponse,
  TimetableResponse,
} from "@honey/shared/api";
import type { HoneyClient } from "./client";

const now = Date.now();
const day = 86_400_000;
const today = new Date(now).toISOString().slice(0, 10);

const entityRows: Array<[string, EntityType, string]> = [
  ["teacher:lin", "teacher", "Ms Lin"], ["teacher:chen", "teacher", "Mr Chen"],
  ["teacher:zhou", "teacher", "Ms Zhou"], ["teacher:patel", "teacher", "Dr Patel"],
  ["course:further-maths", "course", "Further Mathematics"], ["course:physics", "course", "Physics"],
  ["course:economics", "course", "Economics"], ["course:english", "course", "English Literature"],
  ["room:403", "room", "Room 403"], ["room:lab-2", "room", "Science Lab 2"],
  ["room:library", "room", "Library"], ["room:canteen", "room", "Canteen"],
  ["dish:curry", "dish", "Curry rice"], ["dish:noodles", "dish", "Tomato noodles"],
];

const entities: EntityRef[] = entityRows.map(([entity_key, type, name]) => ({
  entity_key,
  type,
  name,
  source: "organic",
}));

const voices = [
  "I like how the proofs are built one step at a time. Being called on without warning can still feel intense when I am already lost.",
  "The pace felt much faster this week. He stayed after class and explained the part I had missed without making it awkward.",
  "The discussion was quiet at first, then one question changed the whole lesson. I left thinking about it on the bus home.",
  "Room 403 gets warm after lunch. Sitting near the door made it much easier to concentrate.",
  "Actually good, but not worth the queue after period four.",
  "I could not fully explain why the lesson unsettled me. Nothing dramatic happened; I just needed more time before I could follow again.",
  "The examples were concrete enough that the model finally stopped feeling like a collection of symbols.",
  "The reading was difficult, but the conversation did not punish unfinished thoughts. That made it easier to say what I meant.",
];

interface FixtureContext {
  course: [string, string];
  teacher: [string, string];
  room: [string, string];
}

const contexts: FixtureContext[] = [
  { course: ["further-maths", "Further Mathematics"], teacher: ["lin", "Ms Lin"], room: ["403", "Room 403"] },
  { course: ["physics", "Physics"], teacher: ["chen", "Mr Chen"], room: ["lab-2", "Science Lab 2"] },
  { course: ["economics", "Economics"], teacher: ["zhou", "Ms Zhou"], room: ["403", "Room 403"] },
  { course: ["english", "English Literature"], teacher: ["patel", "Dr Patel"], room: ["library", "Library"] },
];

const feed: PublicExperience[] = Array.from({ length: 24 }, (_, index) => {
  const context = contexts[index % contexts.length]!;
  const food = index % 9 === 4;
  const room = index % 9 === 3;
  const primary = food
    ? { type: "dish" as const, id: "curry", name: "Curry rice" }
    : room
      ? { type: "room" as const, id: context.room[0], name: context.room[1] }
      : { type: "teacher" as const, id: context.teacher[0], name: context.teacher[1] };
  return {
    id: `fixture-${index + 1}`,
    entity_key: `${primary.type}:${primary.id}`,
    ctx_teacher_id: food ? null : context.teacher[0],
    ctx_course_id: food ? null : context.course[0],
    ctx_room_id: food ? "canteen" : context.room[0],
    body: voices[index % voices.length]!,
    rating: food ? 4 : null,
    provenance: food ? "verified_member" : index % 3 === 0 ? "verified_lesson" : "verified_retrospective",
    publishedDay: Math.floor((now - index * 6 * 3_600_000) / day),
    reactions: index % 5 === 0 ? null : { likes: 4 + index, dislikes: index % 4 },
    myReaction: 0,
    primary,
    contexts: food ? [{ type: "room", id: "canteen", name: "Canteen" }] : [
      { type: "course", id: context.course[0], name: context.course[1] },
      { type: "teacher", id: context.teacher[0], name: context.teacher[1] },
      { type: "room", id: context.room[0], name: context.room[1] },
    ],
  };
});

function lesson(offsetMinutes: number, duration: number, index: number): Lesson {
  const context = contexts[index % contexts.length]!;
  return {
    id: `lesson-${index + 1}`,
    subjectName: context.course[1],
    topicName: ["Proof by induction", "Electric fields", "Welfare and choice", "Close reading"][index % 4]!,
    teacherId: context.teacher[0], teacherName: context.teacher[1],
    courseId: context.course[0], courseName: context.course[1],
    roomId: context.room[0], roomName: context.room[1],
    startsAt: now + offsetMinutes * 60_000,
    endsAt: now + (offsetMinutes + duration) * 60_000,
  };
}

const lessons = [lesson(-22, 55, 0), lesson(54, 55, 1), lesson(154, 55, 2), lesson(254, 55, 3)];
const me: Me = {
  honeyId: "0088", displayName: "Gary", isAdmin: true,
  consent: { timetable: true, grantedAt: new Date(now - day * 7).toISOString() },
  connection: { connected: true, lastSyncedAt: new Date(now - 12 * 60_000).toISOString(), portalTokenValid: true },
};

export class FixtureClient implements HoneyClient {
  readonly fixtureMode = true;
  onSessionLost: (() => void) | null = null;
  private consent = true;
  private reactions = new Map<string, 1 | -1 | 0>();
  private owned: MyExperience[] = [];

  hasSession(): boolean { return true; }
  async login(_input: LoginInput): Promise<LoginResponse> {
    return { ...me, created: false, consent: { timetable: this.consent }, session: fixtureSession() };
  }
  async logout(): Promise<void> {}
  async me(): Promise<Me> { return { ...me, consent: { ...me.consent, timetable: this.consent } }; }
  async setConsent(value: boolean): Promise<void> { this.consent = value; }
  async syncSeamless(): Promise<{ result: SyncResponse; reconnected: boolean }> {
    return { result: { status: "ok", lessons: lessons.length, teachers: 4, courses: 4, rooms: 4 }, reconnected: false };
  }
  async nextLesson(): Promise<NextLessonResponse> {
    return { nextLesson: { ...lessons[0]!, temporalState: "now", minutesUntilStart: 0 }, lastSyncedAt: me.connection.lastSyncedAt };
  }
  async timetable(_date: string): Promise<TimetableResponse> { return { date: today, lessons, lastSyncedAt: me.connection.lastSyncedAt }; }
  async history(params: HistoryParams = {}): Promise<HistoryResponse> {
    const count = Math.min(params.limit ?? 24, 24);
    const rows = Array.from({ length: count }, (_, index) => ({ ...lesson(-day / 60_000 * (index + 1), 55, index), id: `history-${index}` }));
    const query = params.q?.toLowerCase();
    return { lessons: query ? rows.filter((item) => `${item.subjectName} ${item.teacherName}`.toLowerCase().includes(query)) : rows };
  }
  async directory(): Promise<DirectoryResponse> {
    const entries = (type: EntityType) => entities.filter((entity) => entity.type === type).map((entity) => ({ id: entity.entity_key.split(":")[1] ?? entity.entity_key, name: entity.name }));
    return { teachers: entries("teacher"), courses: entries("course"), rooms: entries("room") };
  }
  async entities(type?: EntityType, q?: string): Promise<EntitiesResponse> {
    const needle = q?.toLowerCase();
    return { entities: entities.filter((entity) => (!type || entity.type === type) && (!needle || entity.name.toLowerCase().includes(needle))) };
  }
  async feedPage(params: FeedParams): Promise<FeedPage> {
    const start = Number(params.cursor ?? 0);
    let filtered = params.scope === "my_classes" ? feed.filter((item) => item.primary?.type !== "dish") : feed;
    if (params.entityKey) filtered = filtered.filter((item) => item.entity_key === params.entityKey || item.contexts?.some((context) => `${context.type}:${context.id}` === params.entityKey));
    if (params.teacherId) filtered = filtered.filter((item) => item.ctx_teacher_id === params.teacherId);
    if (params.courseId) filtered = filtered.filter((item) => item.ctx_course_id === params.courseId);
    if (params.roomId) filtered = filtered.filter((item) => item.ctx_room_id === params.roomId);
    const pageSize = Math.min(params.limit ?? 12, 20);
    const items = filtered.slice(start, start + pageSize).map((item) => ({ ...item, myReaction: this.reactions.get(item.id) ?? 0 }));
    return { items, nextCursor: start + pageSize < filtered.length ? String(start + pageSize) : null, headCursor: "fixture-head" };
  }
  async feedUpdates(_scope: FeedScope, _head: string): Promise<FeedUpdatesResponse> { return { newItemsAvailable: false }; }
  async experienceEligibility(_input: ExperienceEligibilityInput): Promise<ExperienceEligibilityResponse> { return { ok: true, eligibilityToken: "fixture-eligibility", expiresAt: now + 300_000 }; }
  async checkExperience(input: CheckExperienceInput): Promise<CheckExperienceResponse> {
    if (input.body.includes("[edit]")) return { lane: "edit_required", reasons: ["targeted_wording"], policyVersion: 7 };
    if (input.body.includes("[scope]")) return { lane: "out_of_scope", reasons: ["institutional_consequence"], policyVersion: 7 };
    if (input.body.includes("[cooldown]")) return { lane: "cooldown", reasons: ["elevated_arousal"], policyVersion: 7, cooldown: { ticket: "fixture-ticket", retryAt: now + day } };
    if (input.body.length < 80) return { lane: "nudge", reasons: ["add_context"], policyVersion: 7, pass: "fixture-pass" };
    return { lane: "publish", reasons: [], policyVersion: 7, pass: "fixture-pass" };
  }
  async publishExperience(input: PublishExperienceInput): Promise<PublishExperienceResponse> {
    const id = `owned-${this.owned.length + 1}`;
    this.owned.unshift({ id, entity_key: "teacher:lin", lesson_id: null, ctx_teacher_id: "lin", ctx_course_id: "further-maths", ctx_room_id: null, body: input.body, rating: input.rating ?? null, provenance: "verified_retrospective", status: "published", status_detail: null, policy_version: 7, created_at: now, published_at: now });
    return { ok: true, experienceId: id, ownershipKey: `fixture-key-${id}` };
  }
  async myExperiences(_keys: string[]): Promise<MyExperiencesResponse> { return { experiences: this.owned }; }
  async revokeExperience(_ownershipKey: string): Promise<{ ok: boolean }> { return { ok: true }; }
  async reactToExperience(id: string, value: 1 | -1 | 0): Promise<ReactResponse> {
    this.reactions.set(id, value);
    const item = feed.find((entry) => entry.id === id);
    return { ok: true, value, reactions: item?.reactions ?? null };
  }
  async reportExperience(_id: string, _category: ReportCategory): Promise<{ ok: boolean }> { return { ok: true }; }
  async disconnectSchool(): Promise<void> {}
  async deleteImportedData(): Promise<void> {}
  async deleteAccount(): Promise<void> {}
}

function fixtureSession() {
  return { accessToken: "fixture", accessExpiresAt: new Date(now + day).toISOString(), refreshToken: "fixture", refreshExpiresAt: new Date(now + day * 30).toISOString() };
}

export { entities as fixtureEntities, feed as fixtureFeed, lessons as fixtureLessons };
