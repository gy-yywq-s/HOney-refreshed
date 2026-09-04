// Contract fixtures — typed literals that BOTH clients decode (spec
// HOney_current_web_to_iPhone_native_port §4.1): TypeScript checks them
// against the contracts at compile time (`satisfies`), `fixtures.test.ts`
// pins the checked-in JSON under packages/shared/fixtures/api to these
// literals, and the Swift package's FixtureDecodingTests decode the same
// files. A breaking field/type change fails on both sides; an additive
// server field is exercised by `entities` (extra `active`/`created_at`).
//
// Two contracts live here: the ordinary Core API (api/contract.ts — canonical
// school data, 2026-09) and the identity-free Community v2 wire
// (community-v2/contract.ts — names are null on the wire, clients join them).
//
// Content is deliberately mixed-language and realistic (port spec §28.3):
// canonical courses AL ECON U4 / AL CHIN / IELTS Speaking with their
// operational sections, Chinese teacher names, a long English teacher name,
// rooms 309 / A203, a missing teacher/room, an unresolved label, long and
// short Experiences, hidden and visible reaction counts, every own-post
// state. Times are 2026-09-02 (Wednesday) in Asia/Shanghai, expressed as the
// epoch milliseconds the wire carries.

import type {
  DirectoryResponse,
  EntitiesResponse,
  HistoryResponse,
  LoginResponse,
  Me,
  NextLessonResponse,
  PortalEntryResponse,
  SessionTokens,
  SyncResponse,
  TimetableRangeResponse,
  TimetableResponse,
} from "./contract.js";
import type {
  ChallengeResponse,
  CheckResponseV2,
  CommunityScope,
  EligibilityInfo,
  EligibilityIssued,
  EntityStatsV2,
  FeedPageV2,
  IssuerDescriptor,
  MineResponse,
  PairingDelivery,
  PairingOffer,
  PublicExperienceV2,
  PublishResponseV2,
  SearchResponseV2,
  VaultPutResponse,
  VaultRecord,
} from "../community-v2/contract.js";

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
    subjectId: "s_ielts",
    subjectName: "IELTS",
    courseId: "c_ielts_speaking",
    courseName: "IELTS Speaking",
    classSectionId: "sec_ielts_2026a",
    classSectionName: "2026 Autumn · Intensive Class",
    topicName: null,
    teacherId: "t_23348879d1b4",
    teacherName: "Jennifer Anne Whitcombe-Rasmussen",
    roomId: "r_360",
    roomName: "A203",
    startsAt: sh("2026-09-02", "08:30"),
    endsAt: sh("2026-09-02", "10:00"),
  },
  econ: {
    id: "1325152",
    subjectId: "s_econ",
    subjectName: "Economics",
    courseId: "c_al_econ_u4",
    courseName: "AL ECON U4",
    classSectionId: "sec_econ_2026a",
    classSectionName: "2026 Autumn · Prep Class",
    topicName: null,
    teacherId: "t_76b873b12d89",
    teacherName: "朱昂明",
    roomId: "r_345",
    roomName: "309",
    startsAt: sh("2026-09-02", "13:30"),
    endsAt: sh("2026-09-02", "15:00"),
  },
  activity: {
    id: "1322902",
    subjectId: "s_activity",
    subjectName: "Activity",
    courseId: "c_activity",
    courseName: "Activity",
    classSectionId: "sec_activity_2026a",
    classSectionName: "2026 Autumn · Activity",
    topicName: null,
    teacherId: "t_9e75caffc183",
    teacherName: "活动课老师",
    roomId: "r_df12aeba9bb9",
    roomName: null,
    startsAt: sh("2026-09-02", "16:30"),
    endsAt: sh("2026-09-02", "18:00"),
  },
  chinese: {
    id: "1330001",
    subjectId: "s_chinese",
    subjectName: "Chinese",
    courseId: "c_al_chin",
    courseName: "AL CHIN",
    classSectionId: "sec_chin_2026a",
    classSectionName: "2026 Autumn · Prep Class",
    topicName: null,
    teacherId: "t_zhao",
    teacherName: "赵流畅",
    roomId: null,
    roomName: null,
    startsAt: sh("2026-09-03", "10:30"),
    endsAt: sh("2026-09-03", "12:00"),
  },
  physics: {
    id: "1330002",
    subjectId: "s_physics",
    subjectName: "Physics",
    courseId: "c_al_phys_a2",
    courseName: "AL PHYS A2",
    classSectionId: "sec_phys_2026a_5",
    classSectionName: "2026 Autumn · Prep Class (5)",
    topicName: "Fields",
    teacherId: "t_chen",
    teacherName: "陈拯侃",
    roomId: "r_308",
    roomName: "308",
    startsAt: sh("2026-09-01", "15:00"),
    endsAt: sh("2026-09-01", "16:30"),
  },
  // An unresolved source label: no course, no section — the Subject carries the title.
  saturday: {
    id: "1330003",
    subjectId: null,
    subjectName: "Public Speaking",
    courseId: null,
    courseName: null,
    classSectionId: null,
    classSectionName: null,
    topicName: null,
    teacherId: null,
    teacherName: null,
    roomId: null,
    roomName: null,
    startsAt: sh("2026-09-05", "09:00"),
    endsAt: sh("2026-09-05", "10:30"),
  },
  early: {
    id: "1330004",
    subjectId: "s_reading",
    subjectName: "Morning Reading",
    courseId: null,
    courseName: null,
    classSectionId: null,
    classSectionName: null,
    topicName: null,
    teacherId: null,
    teacherName: null,
    roomId: "r_lib",
    roomName: "Library",
    startsAt: sh("2026-09-04", "08:00"),
    endsAt: sh("2026-09-04", "08:40"),
  },
};

// ---- Community v2 posts (names null on the wire) ---------------------------

const postShort: PublicExperienceV2 = {
  id: "exp_short",
  primary: { type: "lesson", id: "tok_a1", name: null },
  contexts: [
    { type: "course", id: "c_al_econ_u4", name: null },
    { type: "teacher", id: "t_76b873b12d89", name: null },
    { type: "room", id: "r_345", name: null },
  ],
  body: "Econ today actually made sense once the diagrams came out.",
  rating: null,
  provenance: "verified_lesson",
  publishedDay: 20698,
  reactions: { likes: 3, dislikes: 1 },
};

const postLong: PublicExperienceV2 = {
  id: "exp_long",
  primary: { type: "teacher", id: "t_23348879d1b4", name: null },
  contexts: [],
  body:
    "Speaking practice with her is a lot: every session she picks one of us to describe a photo for two full minutes without notes, and the first time it happened I froze completely. What I did not expect is that she never lets the silence become embarrassing — she just waits, then asks one small question that gives you a way back in. Over a few weeks I noticed I stopped rehearsing sentences in my head before speaking, which is exactly the thing the exam needs. It is not a comfortable class. It is one of the few where I can point at what changed. If you are the kind of person who needs to prepare everything in advance you will hate the first month; stay for the second one. I still cannot fully explain why it works, but it does for me, and the two friends I have compared notes with say something similar about the waiting — that the pause is the teaching.",
  rating: null,
  provenance: "verified_retrospective",
  publishedDay: 20690,
  reactions: null,
};

const postDish: PublicExperienceV2 = {
  id: "exp_dish",
  primary: { type: "dish", id: "d_001", name: null },
  contexts: [],
  body: "Sweeter than it looks. Good on a cold day.",
  rating: 4,
  provenance: "verified_member",
  publishedDay: 20695,
  reactions: { likes: 0, dislikes: 0 },
};

const eligibilityInfo: EligibilityInfo = {
  v: 2,
  schoolId: "huayaopudong",
  academicYear: "2026-27",
  scope: "lesson:tok_a1",
  contexts: { lessonId: "tok_a1", courseId: "c_al_econ_u4", teacherId: "t_76b873b12d89", roomId: "r_345" },
  provenance: "verified_lesson",
  week: 36,
};

const vaultRecord: VaultRecord = {
  vaultId: "v_fixture",
  revision: 3,
  iv: "AAAAAAAAAAAAAAAA",
  ciphertext: "Y2lwaGVydGV4dC1maXh0dXJlLWJ5dGVzLW5vdC1yZWFs",
  wrappers: [
    { type: "recovery_phrase", format: "words12-v1", iv: "AQEBAQEBAQEBAQEB", wrappedR: "d3JhcHBlZC1SLWJ5LXBocmFzZQ", createdAt: sh("2026-09-02", "15:20") },
    { type: "passkey_prf", credentialId: "cred_fixture", prfInput: "cHJmLWlucHV0LWZpeHR1cmU", iv: "AgICAgICAgICAgIC", wrappedR: "d3JhcHBlZC1SLWJ5LXByZg", createdAt: sh("2026-09-02", "15:25"), label: "Safari on iPhone" },
  ],
  updatedAt: sh("2026-09-02", "15:25"),
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
      { id: "c_al_econ_u4", name: "AL ECON U4" },
      { id: "c_al_chin", name: "AL CHIN" },
      { id: "c_ielts_speaking", name: "IELTS Speaking" },
    ],
    rooms: [
      { id: "r_345", name: "309" },
      { id: "r_360", name: "A203" },
      { id: "r_lib", name: "Library" },
    ],
  } satisfies DirectoryResponse,

  sync: { status: "ok", lessons: 126, teachers: 6, courses: 8, rooms: 10, unresolved: 1 } satisfies SyncResponse,

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
      { entity_key: "course:c_al_econ_u4", type: "course", name: "AL ECON U4", source: "organic" },
      { entity_key: "course:c_al_chin", type: "course", name: "AL CHIN", source: "organic" },
      { entity_key: "room:r_345", type: "room", name: "309", source: "organic" },
      { entity_key: "dish:d_001", type: "dish", name: "番茄炒蛋", source: "admin" },
    ],
  } as EntitiesResponse,

  // ---- Community v2 (identity-free) ---------------------------------------

  "feed-page": {
    items: [postShort, postLong, postDish],
    nextCursor: "cur_opaque_next",
    headCursor: "cur_opaque_head",
  } satisfies FeedPageV2,

  "feed-page-end": { items: [], nextCursor: null, headCursor: null } satisfies FeedPageV2,

  "feed-updates": { newItemsAvailable: true },

  "from-my-classes": { experiences: [postShort] } satisfies { experiences: PublicExperienceV2[] },

  search: { q: "diagrams", experiences: [postShort] } satisfies SearchResponseV2,

  stats: { experiences: 18, courses: 3, teachers: 0 } satisfies EntityStatsV2,

  "check-publish": { lane: "publish", reasons: [], policyVersion: 7, pass: "pass_fixture" } satisfies CheckResponseV2,

  "check-nudge": { lane: "nudge", reasons: ["composition:low_information"], policyVersion: 7, pass: "pass_fixture" } satisfies CheckResponseV2,

  "check-cooldown": {
    lane: "cooldown",
    reasons: ["timing:high_arousal"],
    policyVersion: 7,
    cooldown: { ticket: "cool_fixture", retryAt: sh("2026-09-03", "09:00") },
  } satisfies CheckResponseV2,

  "check-edit-required": { lane: "edit_required", reasons: ["expression:targets_student"], policyVersion: 7 } satisfies CheckResponseV2,

  "check-out-of-scope": { lane: "out_of_scope", reasons: [], policyVersion: 7 } satisfies CheckResponseV2,

  "check-failed-closed": { lane: "failed_closed", reasons: [], policyVersion: 7 } satisfies CheckResponseV2,

  publish: { ok: true, experienceId: "exp_new", postNonce: "oKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr8" } satisfies PublishResponseV2,

  challenge: { challenge: "ch_fixture", expiresAt: sh("2026-09-02", "15:15") } satisfies ChallengeResponse,

  mine: {
    experiences: [
      {
        id: "exp_short",
        primaryEntity: { type: "lesson", id: "tok_a1", name: null },
        contexts: [
          { type: "course", id: "c_al_econ_u4", name: null },
          { type: "teacher", id: "t_76b873b12d89", name: null },
        ],
        body: "Econ today actually made sense once the diagrams came out.",
        rating: null,
        provenance: "verified_lesson",
        status: "published",
        statusDetail: null,
        postNonce: "oKGio6SlpqeoqaqrrK2ur7CxsrO0tba3uLm6u7y9vr8",
        controlPublicKey: "TmDOXP_H06UskXylYiMchd0IVIFNA-QJYp8Bwy_AAvI",
        createdAt: sh("2026-09-02", "15:12"),
      },
      {
        id: "exp_hidden",
        primaryEntity: { type: "teacher", id: "t_zhao", name: null },
        contexts: [],
        body: "Hidden after a re-check.",
        rating: null,
        provenance: "verified_retrospective",
        status: "blocked",
        statusDetail: "Re-checked under policy v7.",
        postNonce: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8",
        controlPublicKey: "BQZL0HQ4N972dKgA31iq-lOmQFdUKWxR2_-ZZfG1Z1Q",
        createdAt: sh("2026-08-28", "18:40"),
      },
    ],
  } satisfies MineResponse,

  react: { ok: true, value: -1, reactions: { likes: 3, dislikes: 2 } },

  "react-hidden": { ok: true, value: 1, reactions: null },

  // ---- Core: issuer, scope, eligibility, Control Vault, pairing ------------

  issuer: {
    suite: "RSAPBSSA-SHA384-PSS-Randomized",
    keyId: "issuer-fixture",
    publicKey: { kty: "RSA", n: "yGVsSCvi7A0oPm3B4sxBNv8vJb7l6Q9Vh4S3pJqXzFixture", e: "AQAB", alg: "PS384" },
  } satisfies IssuerDescriptor,

  scope: {
    schoolId: "huayaopudong",
    academicYear: "2026-27",
    teachers: ["t_76b873b12d89", "t_23348879d1b4", "t_9e75caffc183", "t_zhao"],
    courses: ["c_al_econ_u4", "c_al_chin", "c_ielts_speaking"],
    lessons: ["tok_a1", "tok_b2"],
  } satisfies CommunityScope,

  "eligibility-info": { ok: true, info: eligibilityInfo } satisfies { ok: true; info: EligibilityInfo },

  "eligibility-issued": {
    ok: true,
    keyId: "issuer-fixture",
    info: eligibilityInfo,
    blindSignature: "YmxpbmQtc2lnbmF0dXJlLWZpeHR1cmU",
  } satisfies EligibilityIssued,

  "vault-record": vaultRecord satisfies VaultRecord,

  "vault-put-ok": { ok: true, revision: 4, updatedAt: sh("2026-09-02", "15:30") } satisfies VaultPutResponse,

  "vault-put-conflict": { ok: false, error: "conflict", current: vaultRecord } satisfies VaultPutResponse,

  "pairing-offer": { pairingId: "pair_fixture", recipientPublicKey: "cmVjaXBpZW50LXB1YmxpYy1rZXktZml4dHVyZS0zMmI", expiresAt: sh("2026-09-02", "15:40") } satisfies PairingOffer,

  "pairing-delivery": { pairingId: "pair_fixture", enc: "ZW5jLWZpeHR1cmU", ciphertext: "Y2lwaGVydGV4dC1maXh0dXJl" } satisfies PairingDelivery,

  error: { error: "publications_disabled" },
};
