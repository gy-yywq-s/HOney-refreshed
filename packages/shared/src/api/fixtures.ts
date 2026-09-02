// Contract fixtures — typed literals that BOTH clients decode (spec
// HOney_current_web_to_iPhone_native_port §4.1): TypeScript checks them
// against contract.ts at compile time (`satisfies`), `fixtures.test.ts`
// pins the checked-in JSON under packages/shared/fixtures/api to these
// literals, and the Swift package's FixtureDecodingTests decode the same
// files. A breaking field/type change fails on both sides; an additive
// server field is exercised by `entities` (extra `active`/`created_at`).
//
// Content is deliberately mixed-language and realistic (port spec §28.3):
// Edexcel Economics-U4, CIE Chinese Language & Literature, IELTS-Speaking,
// Chinese teacher names, a long English teacher name, rooms 309 / A203, a
// missing teacher/room, long and short Experiences, hidden and visible
// reaction counts, every own-post state. Times are 2026-09-02 (Wednesday)
// in Asia/Shanghai, expressed as the epoch milliseconds the wire carries.

import type {
  CheckExperienceResponse,
  DirectoryResponse,
  EntitiesResponse,
  EntityStats,
  ExperienceEligibilityResponse,
  ExperiencesFeedResponse,
  FeedPage,
  FeedUpdatesResponse,
  HistoryResponse,
  LoginResponse,
  Me,
  MyExperiencesResponse,
  NextLessonResponse,
  PortalEntryResponse,
  PublishExperienceResponse,
  ReactResponse,
  SearchResponse,
  SessionTokens,
  SyncResponse,
  TimetableRangeResponse,
  TimetableResponse,
} from "./contract.js";

/** Asia/Shanghai wall clock → epoch ms (UTC+8, no DST). */
function sh(date: string, time: string): number {
  return Date.parse(`${date}T${time}:00+08:00`);
}

const session = {
  accessToken: "acc_fixture_token",
  accessExpiresAt: "2026-09-02T09:30:00.000Z",
  refreshToken: "ref_fixture_token",
  refreshExpiresAt: "2026-10-02T09:00:00.000Z",
} satisfies SessionTokens;

const lessons = {
  ielts: {
    id: "1335340",
    subjectName: "IELTS-Speaking",
    topicName: "IELTS-Speaking",
    teacherId: "t_23348879d1b4",
    teacherName: "Jennifer Anne Whitcombe-Rasmussen",
    courseId: "c_56081",
    courseName: "IELTS-Speaking 2026秋IELTS Speaking强化班 Jennifer Anne Whitcombe-Rasmussen",
    roomId: "r_360",
    roomName: "A203",
    startsAt: sh("2026-09-02", "08:30"),
    endsAt: sh("2026-09-02", "10:00"),
  },
  econ: {
    id: "1325152",
    subjectName: "Edexcel Economics-U4",
    topicName: "Edexcel Economics-U4",
    teacherId: "t_76b873b12d89",
    teacherName: "朱昂明",
    courseId: "c_55566",
    courseName: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明",
    roomId: "r_345",
    roomName: "309",
    startsAt: sh("2026-09-02", "13:30"),
    endsAt: sh("2026-09-02", "15:00"),
  },
  activity: {
    id: "1322902",
    subjectName: "Activity",
    topicName: "Activity",
    teacherId: "t_9e75caffc183",
    teacherName: "活动课老师",
    courseId: "c_55456",
    courseName: "Activity 2026年秋活动课 活动课老师",
    roomId: "r_df12aeba9bb9",
    roomName: null,
    startsAt: sh("2026-09-02", "16:30"),
    endsAt: sh("2026-09-02", "18:00"),
  },
  chinese: {
    id: "1330001",
    subjectName: "CIE Chinese Language & Literature",
    topicName: null,
    teacherId: "t_zhao",
    teacherName: "赵流畅",
    courseId: "c_55738",
    courseName: "CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅",
    roomId: null,
    roomName: null,
    startsAt: sh("2026-09-03", "10:30"),
    endsAt: sh("2026-09-03", "12:00"),
  },
  physics: {
    id: "1330002",
    subjectName: "CIE Physics-A2",
    topicName: "Fields",
    teacherId: "t_chen",
    teacherName: "陈拯侃",
    courseId: "c_55800",
    courseName: "CIE Physics-A2 2026秋A2PHY备考5班 陈拯侃",
    roomId: "r_308",
    roomName: "308",
    startsAt: sh("2026-09-01", "15:00"),
    endsAt: sh("2026-09-01", "16:30"),
  },
  saturday: {
    id: "1330003",
    subjectName: "Public Speaking",
    topicName: null,
    teacherId: null,
    teacherName: null,
    courseId: null,
    courseName: null,
    roomId: null,
    roomName: null,
    startsAt: sh("2026-09-05", "09:00"),
    endsAt: sh("2026-09-05", "10:30"),
  },
  early: {
    id: "1330004",
    subjectName: "Morning Reading",
    topicName: null,
    teacherId: null,
    teacherName: null,
    courseId: null,
    courseName: null,
    roomId: null,
    roomName: "Library",
    startsAt: sh("2026-09-04", "08:00"),
    endsAt: sh("2026-09-04", "08:40"),
  },
};

export const FIXTURES = {
  login: {
    honeyId: "h_fixture01",
    displayName: "沈高远",
    created: false,
    isAdmin: false,
    consent: { timetable: true },
    session,
  } satisfies LoginResponse,

  "session-refresh": session satisfies SessionTokens,

  me: {
    honeyId: "h_fixture01",
    displayName: "沈高远",
    isAdmin: true,
    consent: { timetable: true, grantedAt: "2026-09-01T16:51:24.747Z" },
    connection: { connected: true, lastSyncedAt: "2026-09-02T06:40:46.298Z", portalTokenValid: true },
  } satisfies Me,

  "me-disconnected": {
    honeyId: "h_fixture02",
    displayName: "Alex",
    isAdmin: false,
    consent: { timetable: true, grantedAt: null },
    connection: { connected: false, lastSyncedAt: null, portalTokenValid: false },
  } satisfies Me,

  "next-lesson-now": {
    nextLesson: { ...lessons.activity, temporalState: "now", minutesUntilStart: 0 },
    lastSyncedAt: "2026-09-02T06:40:46.298Z",
  } satisfies NextLessonResponse,

  "next-lesson-upcoming": {
    nextLesson: { ...lessons.chinese, temporalState: "upcoming", minutesUntilStart: 1064 },
    lastSyncedAt: "2026-09-02T06:40:46.298Z",
  } satisfies NextLessonResponse,

  "next-lesson-none": { nextLesson: null, lastSyncedAt: null } satisfies NextLessonResponse,

  "timetable-day": {
    date: "2026-09-02",
    lessons: [lessons.ielts, lessons.econ, lessons.activity],
    lastSyncedAt: "2026-09-02T06:40:46.298Z",
  } satisfies TimetableResponse,

  "timetable-range": {
    from: "2026-08-31",
    to: "2026-09-06",
    days: [
      { date: "2026-08-31", lessons: [] },
      { date: "2026-09-01", lessons: [lessons.physics] },
      { date: "2026-09-02", lessons: [lessons.ielts, lessons.econ, lessons.activity] },
      { date: "2026-09-03", lessons: [lessons.chinese] },
      { date: "2026-09-04", lessons: [lessons.early] },
      { date: "2026-09-05", lessons: [lessons.saturday] },
      { date: "2026-09-06", lessons: [] },
    ],
    lastSyncedAt: "2026-09-02T06:40:46.298Z",
  } satisfies TimetableRangeResponse,

  history: {
    lessons: [lessons.activity, lessons.econ, lessons.ielts, lessons.physics],
  } satisfies HistoryResponse,

  directory: {
    teachers: [
      { id: "t_76b873b12d89", name: "朱昂明" },
      { id: "t_23348879d1b4", name: "Jennifer Anne Whitcombe-Rasmussen" },
      { id: "t_9e75caffc183", name: "活动课老师" },
      { id: "t_zhao", name: "赵流畅" },
    ],
    courses: [
      { id: "c_55566", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明" },
      { id: "c_55738", name: "CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅" },
      { id: "c_56081", name: "IELTS-Speaking 2026秋IELTS Speaking强化班 Jennifer Anne Whitcombe-Rasmussen" },
    ],
    rooms: [
      { id: "r_345", name: "309" },
      { id: "r_360", name: "A203" },
      { id: "r_lib", name: "Library" },
    ],
  } satisfies DirectoryResponse,

  sync: { status: "ok", lessons: 126, teachers: 6, courses: 8, rooms: 10 } satisfies SyncResponse,

  "sync-reconnect": { status: "portal_reconnect_required", lessons: 0, teachers: 0, courses: 0, rooms: 0 } satisfies SyncResponse,

  "portal-entry-ok": {
    status: "ok",
    url: "https://www.huayaopudong.com/student/login?token=FIXTURE",
    expiresAt: sh("2026-09-03", "14:37"),
  } satisfies PortalEntryResponse,

  "portal-entry-reconnect": { status: "portal_reconnect_required" } satisfies PortalEntryResponse,

  // Carries the additive server fields `active` and `created_at` on purpose.
  entities: {
    entities: [
      { entity_key: "teacher:t_76b873b12d89", type: "teacher", name: "朱昂明", source: "organic", active: 1, created_at: 1788271504140 },
      { entity_key: "teacher:t_23348879d1b4", type: "teacher", name: "Jennifer Anne Whitcombe-Rasmussen", source: "organic" },
      { entity_key: "course:c_55566", type: "course", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明", source: "organic" },
      { entity_key: "course:c_55738", type: "course", name: "CIE Chinese Language & Literature 2026秋CIEAL中文备考班 赵流畅", source: "organic" },
      { entity_key: "room:r_345", type: "room", name: "309", source: "organic" },
      { entity_key: "dish:d_001", type: "dish", name: "番茄炒蛋", source: "admin" },
    ],
  } as EntitiesResponse,

  "feed-page": {
    items: [
      {
        id: "exp_short",
        entity_key: "lesson:tok_a1",
        ctx_teacher_id: "t_76b873b12d89",
        ctx_course_id: "c_55566",
        ctx_room_id: "r_345",
        body: "Econ today actually made sense once the diagrams came out.",
        rating: null,
        provenance: "verified_lesson",
        publishedDay: 20698,
        reactions: { likes: 3, dislikes: 1 },
        myReaction: 1,
        primary: { type: "lesson", id: "tok_a1", name: null },
        contexts: [
          { type: "course", id: "c_55566", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明" },
          { type: "teacher", id: "t_76b873b12d89", name: "朱昂明" },
          { type: "room", id: "r_345", name: "309" },
        ],
      },
      {
        id: "exp_long",
        entity_key: "teacher:t_23348879d1b4",
        ctx_teacher_id: null,
        ctx_course_id: null,
        ctx_room_id: null,
        body:
          "Speaking practice with her is a lot: every session she picks one of us to describe a photo for two full minutes without notes, and the first time it happened I froze completely. What I did not expect is that she never lets the silence become embarrassing — she just waits, then asks one small question that gives you a way back in. Over a few weeks I noticed I stopped rehearsing sentences in my head before speaking, which is exactly the thing the exam needs. It is not a comfortable class. It is one of the few where I can point at what changed. If you are the kind of person who needs to prepare everything in advance you will hate the first month; stay for the second one. I still cannot fully explain why it works, but it does for me, and the two friends I have compared notes with say something similar about the waiting — that the pause is the teaching.",
        rating: null,
        provenance: "verified_retrospective",
        publishedDay: 20690,
        reactions: null,
        myReaction: 0,
        primary: { type: "teacher", id: "t_23348879d1b4", name: "Jennifer Anne Whitcombe-Rasmussen" },
        contexts: [],
      },
      {
        id: "exp_dish",
        entity_key: "dish:d_001",
        ctx_teacher_id: null,
        ctx_course_id: null,
        ctx_room_id: null,
        body: "Sweeter than it looks. Good on a cold day.",
        rating: 4,
        provenance: "verified_member",
        publishedDay: 20695,
        reactions: { likes: 0, dislikes: 0 },
        primary: { type: "dish", id: "d_001", name: "番茄炒蛋" },
        contexts: [],
      },
    ],
    nextCursor: "cur_opaque_next",
    headCursor: "cur_opaque_head",
  } satisfies FeedPage,

  "feed-page-end": { items: [], nextCursor: null, headCursor: null } satisfies FeedPage,

  "feed-updates": { newItemsAvailable: true } satisfies FeedUpdatesResponse,

  "from-my-classes": {
    experiences: [
      {
        id: "exp_short",
        entity_key: "lesson:tok_a1",
        ctx_teacher_id: "t_76b873b12d89",
        ctx_course_id: "c_55566",
        ctx_room_id: "r_345",
        body: "Econ today actually made sense once the diagrams came out.",
        rating: null,
        provenance: "verified_lesson",
        publishedDay: 20698,
        reactions: { likes: 3, dislikes: 1 },
        myReaction: 0,
        primary: { type: "lesson", id: "tok_a1", name: null },
        contexts: [
          { type: "course", id: "c_55566", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明" },
          { type: "teacher", id: "t_76b873b12d89", name: "朱昂明" },
        ],
      },
    ],
  } satisfies ExperiencesFeedResponse,

  search: {
    q: "diagrams",
    entities: [{ entity_key: "course:c_55566", type: "course", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明", source: "organic" }],
    experiences: [
      {
        id: "exp_short",
        entity_key: "lesson:tok_a1",
        ctx_teacher_id: "t_76b873b12d89",
        ctx_course_id: "c_55566",
        ctx_room_id: "r_345",
        body: "Econ today actually made sense once the diagrams came out.",
        rating: null,
        provenance: "verified_lesson",
        publishedDay: 20698,
        reactions: { likes: 3, dislikes: 1 },
        myReaction: 1,
        primary: { type: "lesson", id: "tok_a1", name: null },
        contexts: [{ type: "course", id: "c_55566", name: "Edexcel Economics-U4 2026秋EdexcelIALECONU4备考班 朱昂明" }],
      },
    ],
  } satisfies SearchResponse,

  stats: { experiences: 18, courses: 3, teachers: 0 } satisfies EntityStats,

  eligibility: { ok: true, eligibilityToken: "elig_fixture", expiresAt: sh("2026-09-02", "15:10") } satisfies ExperienceEligibilityResponse,

  "check-publish": { lane: "publish", reasons: [], policyVersion: 7, pass: "pass_fixture" } satisfies CheckExperienceResponse,

  "check-nudge": { lane: "nudge", reasons: ["composition:low_information"], policyVersion: 7, pass: "pass_fixture" } satisfies CheckExperienceResponse,

  "check-cooldown": {
    lane: "cooldown",
    reasons: ["timing:high_arousal"],
    policyVersion: 7,
    cooldown: { ticket: "cool_fixture", retryAt: sh("2026-09-03", "09:00") },
  } satisfies CheckExperienceResponse,

  "check-edit-required": { lane: "edit_required", reasons: ["expression:targets_student"], policyVersion: 7 } satisfies CheckExperienceResponse,

  "check-out-of-scope": { lane: "out_of_scope", reasons: [], policyVersion: 7 } satisfies CheckExperienceResponse,

  "check-failed-closed": { lane: "failed_closed", reasons: [], policyVersion: 7 } satisfies CheckExperienceResponse,

  publish: { ok: true, experienceId: "exp_new", ownershipKey: "own_fixture_key" } satisfies PublishExperienceResponse,

  mine: {
    experiences: [
      {
        id: "exp_short",
        entity_key: "lesson:tok_a1",
        lesson_id: "tok_a1",
        ctx_teacher_id: "t_76b873b12d89",
        ctx_course_id: "c_55566",
        ctx_room_id: "r_345",
        body: "Econ today actually made sense once the diagrams came out.",
        rating: null,
        provenance: "verified_lesson",
        status: "published",
        status_detail: null,
        policy_version: 7,
        created_at: sh("2026-09-02", "15:12"),
        published_at: sh("2026-09-02", "15:12"),
      },
      {
        id: "exp_hidden",
        entity_key: "teacher:t_zhao",
        lesson_id: null,
        ctx_teacher_id: null,
        ctx_course_id: null,
        ctx_room_id: null,
        body: "…",
        rating: null,
        provenance: "verified_retrospective",
        status: "blocked",
        status_detail: "Hidden after re-check.",
        policy_version: 7,
        created_at: sh("2026-08-30", "20:00"),
        published_at: sh("2026-08-30", "20:00"),
      },
      {
        id: "exp_gone",
        entity_key: "dish:d_001",
        lesson_id: null,
        ctx_teacher_id: null,
        ctx_course_id: null,
        ctx_room_id: null,
        body: null,
        rating: 2,
        provenance: "verified_member",
        status: "revoked",
        status_detail: null,
        policy_version: 6,
        created_at: sh("2026-08-20", "12:00"),
        published_at: null,
      },
    ],
  } satisfies MyExperiencesResponse,

  react: { ok: true, value: -1, reactions: { likes: 3, dislikes: 2 } } satisfies ReactResponse,

  "react-hidden": { ok: true, value: 1, reactions: null } satisfies ReactResponse,

  error: { error: "entity_unknown" },
} as const;

export type FixtureName = keyof typeof FIXTURES;
