import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { AddressInfo } from "node:net";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { makeMockPortal } from "@honey/portal-connector/testing";
import { buildApp } from "../app.js";
import { lexicalScan } from "./lexicon.js";
import { normalizeText } from "./normalize.js";
import { decide } from "./policy.js";
import type { LlmFeatures } from "./llm.js";

// Acceptance suite — maps onto App A §26.2 launch gates over the TWO-CALL flow
// (audit §3.7/§3.8): check persists nothing, publication only on explicit
// publish with single-use eligibility token + content-bound pass, no author
// fields anywhere, kill switches, one-per-lesson marks, raw-first browsing.

const CLEAN: LlmFeatures = {
  serious_allegation: false,
  targets_student: false,
  slur_or_dehumanizing: false,
  privacy_invasion: false,
  high_arousal: false,
  hearsay: false,
  targeted_profanity: false,
  low_information: false,
  injection_attempt: false,
  uncertain: false,
};

describe("policy engine (deterministic)", () => {
  const base = { lexical: [] as never[], entityType: "lesson", hasRating: false };

  it("ordinary negative opinion publishes", () => {
    expect(decide({ ...base, llm: { ...CLEAN } }).action).toBe("publish");
  });
  it("v7 ordered gates: allegation is Scope; student target / privacy are Expression revisions", () => {
    expect(decide({ ...base, llm: { ...CLEAN, serious_allegation: true } }).action).toBe("blocked_out_of_scope");
    expect(decide({ ...base, llm: { ...CLEAN, targets_student: true } }).action).toBe("rephrase_required");
    expect(decide({ ...base, llm: { ...CLEAN, privacy_invasion: true } }).action).toBe("rephrase_required");
  });
  it("enforcement is ordered — the frontmost unpassed gate answers (review v3 §11.2)", () => {
    // targeted profanity (Expression) + serious allegation (Scope): the user
    // first fixes the wording; only carriable words get a scope verdict.
    const both = decide({ ...base, llm: { ...CLEAN, targeted_profanity: true, serious_allegation: true } });
    expect(both.action).toBe("rephrase_required");
    expect(both.reasons).toEqual(["expression:targeted_profanity"]);
    // Wording fixed → the same substance now reaches Scope.
    const after = decide({ ...base, llm: { ...CLEAN, serious_allegation: true } });
    expect(after.action).toBe("blocked_out_of_scope");
    expect(after.reasons).toEqual(["scope:serious_allegation"]);
    // Standing precedes Expression.
    const standing = decide({ ...base, llm: { ...CLEAN, hearsay: true, targeted_profanity: true } });
    expect(standing.reasons).toEqual(["standing:hearsay"]);
    // Timing only ever fires once everything else passed.
    const timing = decide({ ...base, llm: { ...CLEAN, high_arousal: true, low_information: true } });
    expect(timing.action).toBe("cooldown_24h");
  });
  it("slur → blocked serious; injection → rephrase; uncertain/outage → failed closed", () => {
    expect(decide({ ...base, llm: { ...CLEAN, slur_or_dehumanizing: true } }).action).toBe("blocked_serious");
    expect(decide({ ...base, llm: { ...CLEAN, injection_attempt: true } }).action).toBe("rephrase_required");
    expect(decide({ ...base, llm: { ...CLEAN, uncertain: true } }).action).toBe("rephrase_required");
    expect(decide({ ...base, llm: null }).action).toBe("failed_closed");
  });
  it("high arousal → 24h cooldown", () => {
    expect(decide({ ...base, llm: { ...CLEAN, high_arousal: true } }).action).toBe("cooldown_24h");
  });
  it("scalar rating only for dishes", () => {
    expect(decide({ ...base, hasRating: true, llm: { ...CLEAN } }).action).toBe("rephrase_required");
    expect(decide({ ...base, entityType: "dish", hasRating: true, llm: { ...CLEAN } }).action).toBe("publish");
  });
  it("lexical hard-block beats a clean LLM verdict", () => {
    expect(
      decide({ lexical: ["direct_threat"], llm: { ...CLEAN }, entityType: "lesson", hasRating: false }).action,
    ).toBe("blocked_serious");
  });
});

describe("lexical layer defeats spacing/confusable evasion", () => {
  it("catches spaced and confusable slurs", () => {
    expect(lexicalScan(normalizeText("you are a r e t a r d"))).toContain("slur_or_dehumanizing");
    expect(lexicalScan(normalizeText("what a r3t4rd"))).toContain("slur_or_dehumanizing");
  });
  it("catches threats and doxxing", () => {
    expect(lexicalScan(normalizeText("I will kill you after class"))).toContain("direct_threat");
    expect(lexicalScan(normalizeText("her number is 13912345678"))).toContain("doxxing_pattern");
  });
  it("does not flag ordinary negativity", () => {
    expect(lexicalScan(normalizeText("The lesson was boring and I learned nothing."))).toHaveLength(0);
  });
});

// ---------- end-to-end ----------

let portal: ReturnType<typeof makeMockPortal>;
let app: ReturnType<typeof buildApp>;
let tmp: string;
let auth: { authorization: string };
let honeyId: string;

beforeEach(async () => {
  portal = makeMockPortal();
  await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const addr = portal.app.server.address() as AddressInfo;
  tmp = mkdtempSync(join(tmpdir(), "honey-exp-"));
  app = buildApp({
    portalBaseUrl: `http://127.0.0.1:${addr.port}`,
    dbPath: join(tmp, "test.db"),
    config: { adminStudentId: "88" }, // mock portal's student id → admin in these tests
  });
  app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });

  const res = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { username: "s0088", password: "pw-good" },
  });
  const body = res.json() as { honeyId: string; session: { accessToken: string } };
  honeyId = body.honeyId;
  auth = { authorization: `Bearer ${body.session.accessToken}` };
  await app.inject({ method: "POST", url: "/api/consent", headers: auth, payload: { timetable: true } });
  await app.inject({ method: "POST", url: "/api/sync", headers: auth });
});

afterEach(async () => {
  await app.close();
  await portal.app.close();
  rmSync(tmp, { recursive: true, force: true });
});

async function myLessonId(): Promise<string> {
  const history = await app.inject({ method: "GET", url: "/api/history?limit=1", headers: auth });
  return (history.json() as { lessons: { id: string }[] }).lessons[0]!.id;
}

type Target = { lessonId?: string; entityKey?: string };

async function eligibility(target: Target) {
  const res = await app.inject({ method: "POST", url: "/api/experiences/eligibility", headers: auth, payload: target });
  return { status: res.statusCode, body: res.json() as Record<string, unknown> };
}

async function check(payload: Record<string, unknown>) {
  const res = await app.inject({ method: "POST", url: "/api/experiences/check", headers: auth, payload });
  return { status: res.statusCode, body: res.json() as Record<string, unknown> };
}

/** Publish is deliberately called WITHOUT any session header. */
async function publish(payload: Record<string, unknown>) {
  const res = await app.inject({ method: "POST", url: "/api/experiences/publish", payload });
  return { status: res.statusCode, body: res.json() as Record<string, unknown> };
}

/** Full happy path: eligibility → check → explicit publish. */
async function fullPublish(target: Target, text: string, rating?: number) {
  const elig = await eligibility(target);
  expect(elig.status).toBe(200);
  const payload: Record<string, unknown> = { ...target, body: text };
  if (rating !== undefined) payload.rating = rating;
  const chk = await check(payload);
  expect(chk.status).toBe(200);
  const pub = await publish({
    eligibilityToken: elig.body.eligibilityToken,
    pass: chk.body.pass,
    body: text,
    ...(rating !== undefined ? { rating } : {}),
  });
  return { elig, chk, pub };
}

function storedCount(): number {
  return (app.ctx.db.prepare("SELECT COUNT(*) AS n FROM experiences").get() as unknown as { n: number }).n;
}

describe("two-call publication flow", () => {
  it("clean lesson review: check → publish lane + pass; explicit publish stores it; no author anywhere", async () => {
    const lessonId = await myLessonId();
    const text = "Honestly the pacing was way too fast — I was lost all lesson.";
    const { chk, pub } = await fullPublish({ lessonId }, text);
    expect(chk.body.lane).toBe("publish");
    expect(typeof chk.body.pass).toBe("string");
    expect(pub.status).toBe(200);
    expect(typeof pub.body.ownershipKey).toBe("string");

    // Lesson posts are NOT queryable by raw lesson id (C1); browse the feed.
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const experiences = (feed.json() as { experiences: Record<string, unknown>[] }).experiences;
    expect(experiences).toHaveLength(1);
    expect(experiences[0]!.body).toBe(text); // raw-first: byte-for-byte
    // The public record exposes no raw lesson id, no exact timestamp (C1/S5)
    // and no internal status/policy fields (audit §4.1).
    expect(experiences[0]!.lesson_id).toBeUndefined();
    expect(experiences[0]!.published_at).toBeUndefined();
    expect(experiences[0]!.status).toBeUndefined();
    expect(experiences[0]!.status_detail).toBeUndefined();
    expect(experiences[0]!.policy_version).toBeUndefined();
    expect(typeof experiences[0]!.publishedDay).toBe("number");
    expect(experiences[0]!.provenance).toBe("verified_lesson");
    // No author-ish field in the response…
    const keys = Object.keys(experiences[0]!);
    expect(keys.some((k) => /honey|author|user|student/i.test(k))).toBe(false);
    // …and no author column in storage (launch gate: verified absence),
    // neither on posts nor on the eligibility table (audit §3.7).
    for (const table of ["experiences", "experience_eligibility"]) {
      const cols = app.ctx.db.prepare(`PRAGMA table_info(${table})`).all() as unknown as { name: string }[];
      expect(cols.length).toBeGreaterThan(0);
      expect(cols.some((c) => /honey|author|user|student/i.test(c.name))).toBe(false);
    }
  });

  it("check NEVER persists the draft — publish, blocked and failed lanes alike", async () => {
    const lessonId = await myLessonId();

    // Clean draft: publishable lane, still nothing stored.
    const clean = await check({ lessonId, body: "A clean, ordinary observation." });
    expect(clean.body.lane).toBe("publish");
    expect(storedCount()).toBe(0);

    // Serious lane.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, serious_allegation: true } });
    const secret = "Mr X assaulted someone last week, spread the word.";
    const blocked = await check({ lessonId, body: secret });
    expect(blocked.body.lane).toBe("out_of_scope");
    expect(blocked.body.pass).toBeUndefined();
    expect(storedCount()).toBe(0);

    // Failed-closed lane (LLM outage).
    app.ctx.experiences.llmRunner = async () => ({ ok: false });
    const failed = await check({ lessonId, body: secret });
    expect(failed.body.lane).toBe("failed_closed");
    expect(failed.body.pass).toBeUndefined();
    expect(storedCount()).toBe(0);

    // The rejected text exists NOWHERE in the database file's tables.
    for (const table of ["experiences", "experience_eligibility", "reports", "settings"]) {
      const rows = app.ctx.db.prepare(`SELECT * FROM ${table}`).all() as Record<string, unknown>[];
      expect(JSON.stringify(rows)).not.toContain("assaulted");
    }
    // The user can immediately try a compliant draft — no mark was burned.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    const retry = await fullPublish({ lessonId }, "The lesson felt rushed.");
    expect(retry.pub.status).toBe(200);
  });

  it("lexical threat blocks WITHOUT calling the LLM", async () => {
    let llmCalls = 0;
    app.ctx.experiences.llmRunner = async () => {
      llmCalls++;
      return { ok: true, features: { ...CLEAN } };
    };
    const lessonId = await myLessonId();
    const r = await check({ lessonId, body: "I will kill you Mr Zhang" });
    expect(r.body.lane).toBe("blocked_serious");
    expect(llmCalls).toBe(0);
    expect(storedCount()).toBe(0);
  });

  it("publish requires BOTH artifacts; replay of either fails", async () => {
    const lessonId = await myLessonId();
    const text = "Perfectly reasonable lesson note.";
    // Two eligibility tokens issued up front (mark is only claimed at publish).
    const elig1 = await eligibility({ lessonId });
    const elig2 = await eligibility({ lessonId });
    const chk = await check({ lessonId, body: text });
    expect(chk.body.lane).toBe("publish");

    // Tampered body → content mismatch.
    const tampered = await publish({
      eligibilityToken: elig1.body.eligibilityToken, pass: chk.body.pass, body: text + " EDITED",
    });
    expect(tampered.status).toBe(422);
    expect(tampered.body.error).toBe("pass_content_mismatch");

    // Garbage artifacts.
    expect((await publish({ eligibilityToken: "nope", pass: chk.body.pass, body: text })).body.error).toBe("eligibility_invalid");
    expect((await publish({ eligibilityToken: elig1.body.eligibilityToken, pass: "nope", body: text })).body.error).toBe("pass_invalid");

    // The real publish.
    const ok = await publish({ eligibilityToken: elig1.body.eligibilityToken, pass: chk.body.pass, body: text });
    expect(ok.status).toBe(200);

    // Replay the eligibility token (with the same pass) → single-use.
    const replayElig = await publish({ eligibilityToken: elig1.body.eligibilityToken, pass: chk.body.pass, body: text });
    expect(replayElig.status).toBe(422);
    expect(replayElig.body.error).toBe("eligibility_used");

    // Replay the pass with the OTHER (unused) eligibility token → nonce burned.
    const replayPass = await publish({ eligibilityToken: elig2.body.eligibilityToken, pass: chk.body.pass, body: text });
    expect(replayPass.status).toBe(422);
    expect(replayPass.body.error).toBe("pass_invalid");

    expect(storedCount()).toBe(1);
  });

  it("nudge lane: nothing publishes until the user's explicit choice", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, low_information: true } });
    const lessonId = await myLessonId();
    const elig = await eligibility({ lessonId });
    const chk = await check({ lessonId, body: "ok" });
    expect(chk.body.lane).toBe("nudge");
    expect(typeof chk.body.pass).toBe("string"); // publish-as-is is the user's right

    // The server did NOT auto-publish.
    expect(storedCount()).toBe(0);
    const feed0 = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed0.json() as { experiences: unknown[] }).experiences).toHaveLength(0);

    // Explicit user choice: publish as-is.
    const pub = await publish({ eligibilityToken: elig.body.eligibilityToken, pass: chk.body.pass, body: "ok" });
    expect(pub.status).toBe(200);
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(1);
  });

  it("cooldown lane: ticket-gated re-check; window must elapse; then publishes under current policy", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, high_arousal: true } });
    const lessonId = await myLessonId();
    const text = "ABSOLUTELY FURIOUS about how this lesson went!!!";
    const first = await check({ lessonId, body: text });
    expect(first.body.lane).toBe("cooldown");
    expect(first.body.pass).toBeUndefined(); // no publishing artifact yet
    const cooldown = first.body.cooldown as { ticket: string; retryAt: number };
    expect(cooldown.retryAt).toBeGreaterThan(Date.now() + 23 * 3600 * 1000);
    expect(storedCount()).toBe(0); // draft stays client-side

    // Re-check before the window → still cooldown, same retryAt.
    const early = await check({ lessonId, body: text, cooldownTicket: cooldown.ticket });
    expect(early.body.lane).toBe("cooldown");
    expect((early.body.cooldown as { retryAt: number }).retryAt).toBe(cooldown.retryAt);

    // A forged/mismatched ticket is rejected.
    const forged = await check({ lessonId, body: text + "!", cooldownTicket: cooldown.ticket });
    expect(forged.status).toBe(422);
    expect(forged.body.error).toBe("cooldown_ticket_invalid");

    // Window elapses (injected clock): a repeat high-arousal verdict no longer
    // re-cools — reconfirm publishes ordinary opinion (§13.3) via a fresh pass.
    app.ctx.experiences.now = () => Date.now() + 25 * 3600 * 1000;
    const late = await check({ lessonId, body: text, cooldownTicket: cooldown.ticket });
    expect(late.body.lane).toBe("publish");
    const elig = await eligibility({ lessonId });
    const pub = await publish({ eligibilityToken: elig.body.eligibilityToken, pass: late.body.pass, body: text });
    expect(pub.status).toBe(200);
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(1);
  });

  it("one review per lesson; revoke frees the slot", async () => {
    const lessonId = await myLessonId();
    const first = await fullPublish({ lessonId }, "First take.");
    expect(first.pub.status).toBe(200);

    // Both eligibility and check now refuse the same lesson.
    expect((await eligibility({ lessonId })).body.error).toBe("already_reviewed");
    expect((await check({ lessonId, body: "Second take." })).body.error).toBe("already_reviewed");

    const revoke = await app.inject({
      method: "POST", url: "/api/experiences/revoke", headers: auth,
      payload: { ownershipKey: first.pub.body.ownershipKey },
    });
    expect(revoke.statusCode).toBe(200);
    const again = await fullPublish({ lessonId }, "Recon­sidered take.");
    expect(again.pub.status).toBe(200);
  });

  it("mine: client-held keys see own published (and later hidden) posts", async () => {
    const lessonId = await myLessonId();
    const { pub } = await fullPublish({ lessonId }, "A fine observation about the class.");
    const mine = await app.inject({
      method: "POST", url: "/api/experiences/mine", headers: auth,
      payload: { keys: [pub.body.ownershipKey] },
    });
    const rows = (mine.json() as { experiences: Record<string, unknown>[] }).experiences;
    expect(rows).toHaveLength(1);
    expect(rows[0]!.status).toBe("published");
    expect(rows[0]!.ownership_hash).toBeUndefined();
    expect(rows[0]!.content_hash).toBeUndefined();
  });
});

describe("standalone entities & eligibility", () => {
  it("verified mode: teacher review allowed with exposure; dish needs admin import; rating rules hold", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const tr = await fullPublish({ entityKey: teacher.entity_key }, "Very patient across a whole term.");
    expect(tr.pub.status).toBe(200);

    // Rating on a teacher is refused outright.
    const rated = await check({ entityKey: teacher.entity_key, body: "5 stars", rating: 5 });
    expect(rated.body.error).toBe("rating_not_allowed");

    // Dish: admin imports it; rating 1–5 allowed.
    await app.inject({
      method: "POST", url: "/api/admin/entities/import", headers: auth,
      payload: { items: [{ type: "dish", name: "麻婆豆腐" }] },
    });
    const dishes = await app.inject({ method: "GET", url: "/api/entities?type=dish", headers: auth });
    const dish = (dishes.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const dr = await fullPublish({ entityKey: dish.entity_key }, "Solid, a bit oily.", 4);
    expect(dr.pub.status).toBe(200);
  });

  it("closed mode blocks everyone; invite mode admits only invited students", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;

    await app.inject({
      method: "POST", url: "/api/admin/standalone-mode", headers: auth,
      payload: { scope: "type.teacher", mode: "closed" },
    });
    expect((await eligibility({ entityKey: teacher.entity_key })).body.error).toBe("standalone_closed");

    await app.inject({
      method: "POST", url: "/api/admin/standalone-mode", headers: auth,
      payload: { scope: "type.teacher", mode: "invite" },
    });
    expect((await eligibility({ entityKey: teacher.entity_key })).body.error).toBe("not_invited");

    await app.inject({
      method: "POST", url: "/api/admin/invite", headers: auth,
      payload: { entityKey: teacher.entity_key, studentId: "88" },
    });
    const invited = await fullPublish({ entityKey: teacher.entity_key }, "Good teacher, invited take.");
    expect(invited.pub.status).toBe(200);
  });

  it("admin import unions with organic (same name merges)", async () => {
    const res = await app.inject({
      method: "POST", url: "/api/admin/entities/import", headers: auth,
      payload: { items: [{ type: "teacher", name: "Ms Mock" }, { type: "teacher", name: "Mr Brand-New" }] },
    });
    const body = res.json() as { added: number; merged: number };
    expect(body.merged).toBe(1); // "Ms Mock" already organic
    expect(body.added).toBe(1);
  });
});

describe("from-my-classes (domain query, audit §4.2)", () => {
  it("returns only exposure-relevant published posts, newest first, with before-pagination", async () => {
    const lessonId = await myLessonId();
    await fullPublish({ lessonId }, "Lesson note from my own class.");

    // A dish post is published but is NOT exposure-relevant.
    await app.inject({
      method: "POST", url: "/api/admin/entities/import", headers: auth,
      payload: { items: [{ type: "dish", name: "Fried rice" }] },
    });
    const dishes = await app.inject({ method: "GET", url: "/api/entities?type=dish", headers: auth });
    const dish = (dishes.json() as { entities: { entity_key: string }[] }).entities[0]!;
    await fullPublish({ entityKey: dish.entity_key }, "Decent portion size.");

    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(2);

    const mine = await app.inject({ method: "GET", url: "/api/experiences/from-my-classes", headers: auth });
    const rows = (mine.json() as { experiences: { body: string }[] }).experiences;
    expect(rows).toHaveLength(1);
    expect(rows[0]!.body).toBe("Lesson note from my own class.");

    // before= pagination: nothing published before the epoch+1ms.
    const paged = await app.inject({ method: "GET", url: "/api/experiences/from-my-classes?before=1", headers: auth });
    expect((paged.json() as { experiences: unknown[] }).experiences).toHaveLength(0);
  });
});

describe("reports are category-only (audit §3.9)", () => {
  async function publishedId(): Promise<string> {
    const lessonId = await myLessonId();
    await fullPublish({ lessonId }, "Reportable but ordinary comment.");
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    return (feed.json() as { experiences: { id: string }[] }).experiences[0]!.id;
  }

  it("rejects free-text notes and unknown categories; storage has no note column", async () => {
    const id = await publishedId();
    const withNote = await app.inject({
      method: "POST", url: `/api/experiences/${id}/report`, headers: auth,
      payload: { category: "slur", note: "he also said..." },
    });
    expect(withNote.statusCode).toBe(400);
    expect((withNote.json() as { error: string }).error).toBe("free_text_not_accepted");

    const unknown = await app.inject({
      method: "POST", url: `/api/experiences/${id}/report`, headers: auth,
      payload: { category: "i_disagree" },
    });
    expect(unknown.statusCode).toBe(400);
    expect((unknown.json() as { error: string }).error).toBe("bad_category");

    const cols = app.ctx.db.prepare("PRAGMA table_info(reports)").all() as unknown as { name: string }[];
    expect(cols.some((c) => c.name === "note")).toBe(false);
  });

  it("valid category triggers automatic re-evaluation under current policy", async () => {
    const id = await publishedId();
    // Policy has hardened since publication: the same text now blocks.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, targets_student: true } });
    const rep = await app.inject({
      method: "POST", url: `/api/experiences/${id}/report`, headers: auth,
      payload: { category: "targets_student" },
    });
    expect(rep.statusCode).toBe(200);
    const row = app.ctx.db.prepare("SELECT status, body FROM experiences WHERE id = ?").get(id) as unknown as {
      status: string; body: string | null;
    };
    expect(row.status).toBe("blocked");
    expect(row.body).toBeNull(); // hidden content is purged, not archived
  });
});

describe("cursor feed + course entity (review v3 \u00a712.5/\u00a712.6)", () => {
  async function myTeacherAndCourse(): Promise<{ teacherId: string; courseId: string }> {
    const history = await app.inject({ method: "GET", url: "/api/history?limit=20", headers: auth });
    const lessons = (history.json() as { lessons: { teacherId: string | null; courseId: string | null }[] }).lessons;
    const withT = lessons.find((l) => l.teacherId && l.courseId)!;
    return { teacherId: withT.teacherId!, courseId: withT.courseId! };
  }

  function insertPost(n: number, entityKey: string, t: number, teacherCtx: string | null = null) {
    const id = `exp-feed-${String(n).padStart(3, "0")}`;
    app.ctx.db
      .prepare(
        `INSERT INTO experiences (id, entity_key, lesson_id, ctx_teacher_id, ctx_course_id, ctx_room_id,
           body, rating, provenance, status, status_detail, ownership_hash, content_hash, policy_version, created_at, published_at)
         VALUES (?, ?, NULL, ?, NULL, NULL, ?, NULL, 'verified_retrospective', 'published', NULL, ?, 'ch', 7, ?, ?)`,
      )
      .run(id, entityKey, teacherCtx, `Feed post ${n}.`, `oh-feed-${n}`, t, t);
    const sep = entityKey.indexOf(":");
    app.ctx.db
      .prepare(
        "INSERT OR IGNORE INTO experience_associations (experience_id, entity_type, entity_id, relationship) VALUES (?, ?, ?, 'primary')",
      )
      .run(id, entityKey.slice(0, sep), entityKey.slice(sep + 1), );
    if (teacherCtx) {
      app.ctx.db
        .prepare(
          "INSERT OR IGNORE INTO experience_associations (experience_id, entity_type, entity_id, relationship) VALUES (?, 'teacher', ?, 'context')",
        )
        .run(id, teacherCtx);
    }
    return id;
  }

  async function fetchPage(qs: string) {
    const res = await app.inject({ method: "GET", url: `/api/experiences/feed?${qs}`, headers: auth });
    return { status: res.statusCode, body: res.json() as {
      items: { id: string; primary?: { type: string; id: string; name: string | null }; myReaction?: number }[];
      nextCursor: string | null; headCursor: string | null; error?: string;
    } };
  }

  it("pages the scoped stream without gaps or duplicates; payload carries named context", async () => {
    const { teacherId } = await myTeacherAndCourse();
    for (let i = 0; i < 12; i++) insertPost(i, `teacher:${teacherId}`, 10_000 + i * 100);
    const seen: string[] = [];
    let cursor: string | null = null;
    let head: string | null = null;
    for (let page = 0; page < 5; page++) {
      const q = `scope=my_classes&limit=5${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`;
      const { status, body } = await fetchPage(q);
      expect(status).toBe(200);
      if (page === 0) {
        head = body.headCursor;
        expect(head).not.toBeNull();
        // Complete domain payload: no client directory join needed (§12.4).
        expect(body.items[0]!.primary!.type).toBe("teacher");
        expect(body.items[0]!.primary!.name).not.toBeNull();
      }
      seen.push(...body.items.map((i) => i.id));
      cursor = body.nextCursor;
      if (!cursor) break;
    }
    expect(new Set(seen).size).toBe(12); // no dups
    expect(seen).toHaveLength(12); // no gaps

    // The quiet probe: nothing new yet…
    const q1 = await app.inject({
      method: "GET",
      url: `/api/experiences/feed/updates?scope=my_classes&head=${encodeURIComponent(head!)}`,
      headers: auth,
    });
    expect((q1.json() as { newItemsAvailable: boolean }).newItemsAvailable).toBe(false);
    // …until a newer post lands.
    insertPost(99, `teacher:${teacherId}`, 99_999);
    const q2 = await app.inject({
      method: "GET",
      url: `/api/experiences/feed/updates?scope=my_classes&head=${encodeURIComponent(head!)}`,
      headers: auth,
    });
    expect((q2.json() as { newItemsAvailable: boolean }).newItemsAvailable).toBe(true);
  });

  it("garbage limit never reaches SQL (review M1); empty feed still arms the probe (L4)", async () => {
    // limit=abc used to interpolate LIMIT NaN into the SQL → 500.
    const bad = await fetchPage("scope=my_classes&limit=abc");
    expect(bad.status).toBe(200);

    // A user with exposure but an EMPTY feed gets a zero-position head, so
    // the very first post still triggers the new-posts banner.
    const empty = await fetchPage("scope=my_classes");
    expect(empty.body.items).toHaveLength(0);
    expect(empty.body.headCursor).not.toBeNull();
    const q0 = await app.inject({
      method: "GET",
      url: `/api/experiences/feed/updates?scope=my_classes&head=${encodeURIComponent(empty.body.headCursor!)}`,
      headers: auth,
    });
    expect((q0.json() as { newItemsAvailable: boolean }).newItemsAvailable).toBe(false);
    const { teacherId } = await myTeacherAndCourse();
    insertPost(200, `teacher:${teacherId}`, 50_000);
    const q1 = await app.inject({
      method: "GET",
      url: `/api/experiences/feed/updates?scope=my_classes&head=${encodeURIComponent(empty.body.headCursor!)}`,
      headers: auth,
    });
    expect((q1.json() as { newItemsAvailable: boolean }).newItemsAvailable).toBe(true);
  });

  it("cursors are sealed, tamper-checked and scope-bound", async () => {
    const { teacherId } = await myTeacherAndCourse();
    for (let i = 0; i < 6; i++) insertPost(i, `teacher:${teacherId}`, 20_000 + i);
    const { body } = await fetchPage("scope=my_classes&limit=5");
    expect(body.nextCursor).not.toBeNull();
    // A cursor is OPAQUE — it must not decode to anything readable (S5: the
    // exact publish instant lives inside).
    expect(() => JSON.parse(Buffer.from(body.nextCursor!, "base64url").toString("utf8"))).toThrow();
    // Wrong scope → rejected.
    const wrong = await fetchPage(`scope=school&limit=5&cursor=${encodeURIComponent(body.nextCursor!)}`);
    expect(wrong.status).toBe(400);
    expect(wrong.body.error).toBe("bad_cursor");
    // Garbage → rejected.
    const garbage = await fetchPage("scope=my_classes&cursor=not-a-cursor");
    expect(garbage.status).toBe(400);
  });

  it("light adjacency diversity: at most two consecutive posts per primary entity", async () => {
    const { teacherId, courseId } = await myTeacherAndCourse();
    // Newest-first raw order: T T T C — the third T defers past C.
    insertPost(1, `course:${courseId}`, 30_000);
    insertPost(2, `teacher:${teacherId}`, 30_001);
    insertPost(3, `teacher:${teacherId}`, 30_002);
    insertPost(4, `teacher:${teacherId}`, 30_003);
    const { body } = await fetchPage("scope=my_classes&limit=10");
    const keys = body.items.map((i) => i.primary!.type);
    expect(keys).toEqual(["teacher", "teacher", "course", "teacher"]);
  });

  it("course is a first-class browse entity and retrospective target (§9.10)", async () => {
    const { courseId } = await myTeacherAndCourse();
    const list = await app.inject({ method: "GET", url: "/api/entities?type=course", headers: auth });
    const entities = (list.json() as { entities: { entity_key: string; type: string; name: string }[] }).entities;
    expect(entities.length).toBeGreaterThan(0);
    expect(entities.some((e) => e.entity_key === `course:${courseId}`)).toBe(true);

    // Verified exposure → standalone course retrospective publishes.
    await fullPublish({ entityKey: `course:${courseId}` }, "The pace across this course was fair.");
    const feed = await app.inject({
      method: "GET",
      url: `/api/experiences?courseId=${encodeURIComponent(courseId)}`,
      headers: auth,
    });
    const rows = (feed.json() as { experiences: { entity_key: string; provenance: string }[] }).experiences;
    expect(rows.some((r) => r.entity_key === `course:${courseId}` && r.provenance === "verified_retrospective")).toBe(true);
  });
});

describe("report re-evaluation is tri-state (review v3 \u00a712.15B)", () => {
  /** Insert a published row directly (distinct posts without lesson-dedup limits). */
  function insertPublished(n: number): string {
    const id = `exp-tri-${n}`;
    app.ctx.db
      .prepare(
        `INSERT INTO experiences (id, entity_key, lesson_id, ctx_teacher_id, ctx_course_id, ctx_room_id,
           body, rating, provenance, status, status_detail, ownership_hash, content_hash, policy_version, created_at, published_at)
         VALUES (?, 'teacher:t1', NULL, NULL, NULL, NULL, 'An ordinary published comment.', NULL,
                 'verified_retrospective', 'published', NULL, ?, 'ch', 6, 1000, 1000)`,
      )
      .run(id, `oh-${n}`);
    return id;
  }

  async function report(id: string, category = "other_rule") {
    return app.inject({
      method: "POST", url: `/api/experiences/${id}/report`, headers: auth,
      payload: { category },
    });
  }

  it("classifier outage keeps the post public and queues an automatic retry", async () => {
    const id = insertPublished(1);
    app.ctx.experiences.llmRunner = async () => ({ ok: false }); // outage
    const rep = await report(id);
    expect(rep.statusCode).toBe(200);

    // The post already crossed the publication boundary once — an outage must
    // not unpublish it (this used to hide the post).
    const row = app.ctx.db.prepare("SELECT status, body FROM experiences WHERE id = ?").get(id) as unknown as {
      status: string; body: string | null;
    };
    expect(row.status).toBe("published");
    expect(row.body).not.toBeNull();
    const rrow = app.ctx.db
      .prepare("SELECT outcome, retry_at FROM reports WHERE experience_id = ?")
      .get(id) as unknown as { outcome: string; retry_at: number | null };
    expect(rrow.outcome).toBe("reevaluation_pending");
    expect(rrow.retry_at).not.toBeNull();

    // Classifier comes back with a confident violation; the queued retry hides it.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, targets_student: true } });
    const base = Date.now();
    app.ctx.experiences.now = () => base + 31 * 60_000; // past retry_at
    const processed = await app.ctx.experiences.processPendingReevaluations();
    expect(processed).toBe(1);
    const after = app.ctx.db.prepare("SELECT status FROM experiences WHERE id = ?").get(id) as unknown as {
      status: string;
    };
    expect(after.status).toBe("blocked");
    const rafter = app.ctx.db
      .prepare("SELECT outcome, retry_at FROM reports WHERE experience_id = ?")
      .get(id) as unknown as { outcome: string; retry_at: number | null };
    expect(rafter.outcome).toBe("reevaluated_hidden");
    expect(rafter.retry_at).toBeNull();
  });

  it("an uncertain verdict also keeps the current public state (not a violation)", async () => {
    const id = insertPublished(2);
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, uncertain: true } });
    await report(id);
    const row = app.ctx.db.prepare("SELECT status FROM experiences WHERE id = ?").get(id) as unknown as {
      status: string;
    };
    expect(row.status).toBe("published");
    const rrow = app.ctx.db.prepare("SELECT outcome FROM reports WHERE experience_id = ?").get(id) as unknown as {
      outcome: string;
    };
    expect(rrow.outcome).toBe("reevaluation_pending");
  });

  it("repeat reports by the same account are idempotent and never re-run the LLM", async () => {
    const id = insertPublished(3);
    let llmCalls = 0;
    app.ctx.experiences.llmRunner = async () => {
      llmCalls++;
      return { ok: true, features: { ...CLEAN } };
    };
    expect((await report(id)).statusCode).toBe(200);
    expect((await report(id, "slur")).statusCode).toBe(200); // dedup regardless of category
    const count = app.ctx.db.prepare("SELECT COUNT(*) AS n FROM reports WHERE experience_id = ?").get(id) as unknown as {
      n: number;
    };
    expect(count.n).toBe(1);
    expect(llmCalls).toBe(1);
  });

  it("per-account report rate limit (10 per rolling 24h)", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    for (let i = 10; i < 20; i++) {
      expect((await report(insertPublished(i))).statusCode).toBe(200);
    }
    const blocked = await report(insertPublished(30));
    expect(blocked.statusCode).toBe(422);
    expect((blocked.json() as { error: string }).error).toBe("report_rate_limited");
  });

  it("DISABLE_REPORTS kill switch stops the report system", async () => {
    const id = insertPublished(40);
    app.ctx.settings.setKillSwitch("DISABLE_REPORTS", true);
    const rep = await report(id);
    expect(rep.statusCode).toBe(422);
    expect((rep.json() as { error: string }).error).toBe("reports_disabled");
  });
});

describe("reactions, kill switches, abuse, admin gate", () => {
  it("reaction dedup + change + small-cohort hiding", async () => {
    const lessonId = await myLessonId();
    await fullPublish({ lessonId }, "Useful lesson overall.");
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const expId = (feed.json() as { experiences: { id: string }[] }).experiences[0]!.id;

    await app.inject({ method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: 1 } });
    await app.inject({ method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: -1 } });
    const counts = app.ctx.db.prepare("SELECT COUNT(*) AS n FROM reactions").get() as unknown as { n: number };
    expect(counts.n).toBe(1); // one active reaction per user, value changed

    // Hide counts below threshold.
    await app.inject({
      method: "POST", url: "/api/admin/reaction-min-count", headers: auth, payload: { minCount: 5 },
    });
    const hidden = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((hidden.json() as { experiences: { reactions: unknown }[] }).experiences[0]!.reactions).toBeNull();
  });

  it("react echoes authoritative value+counts; feed restores myReaction (§12.15C)", async () => {
    const lessonId = await myLessonId();
    await fullPublish({ lessonId }, "Useful lesson overall, again.");
    const feed0 = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const expId = (feed0.json() as { experiences: { id: string }[] }).experiences[0]!.id;

    const r1 = await app.inject({
      method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: 1 },
    });
    expect(r1.statusCode).toBe(200);
    const body = r1.json() as { ok: boolean; value: number; reactions: { likes: number; dislikes: number } | null };
    expect(body.value).toBe(1);
    expect(body.reactions).toEqual({ likes: 1, dislikes: 0 });

    // A fresh feed fetch (new device / refresh) knows the viewer's reaction.
    const feed1 = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const mine = (feed1.json() as { experiences: { id: string; myReaction: number }[] }).experiences.find(
      (e) => e.id === expId,
    )!;
    expect(mine.myReaction).toBe(1);
  });

  it("lesson-linked reaction eligibility never compares opaque and raw ids (§12.15C)", async () => {
    const lessonId = await myLessonId();
    await fullPublish({ lessonId }, "Teacher-less lesson comment.");
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const expId = (feed.json() as { experiences: { id: string }[] }).experiences[0]!.id;
    // Strip the teacher context: eligibility must still resolve via the OPAQUE
    // lesson-token namespace (previously this compared token vs raw id and
    // wrongly rejected the author's own classmates).
    app.ctx.db.prepare("UPDATE experiences SET ctx_teacher_id = NULL WHERE id = ?").run(expId);
    const r = await app.inject({
      method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: 1 },
    });
    expect(r.statusCode).toBe(200);
    expect((r.json() as { value: number }).value).toBe(1);
  });

  it("kill switches: publications off blocks check AND publish; feed hidden", async () => {
    const lessonId = await myLessonId();
    // Obtain valid artifacts first, then flip the switch: publish must refuse.
    const elig = await eligibility({ lessonId });
    const chk = await check({ lessonId, body: "Fine lesson." });
    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "DISABLE_NEW_PUBLICATIONS", on: true },
    });
    expect((await check({ lessonId, body: "x" })).body.error).toBe("publications_disabled");
    expect((await eligibility({ lessonId })).body.error).toBe("publications_disabled");
    const pub = await publish({ eligibilityToken: elig.body.eligibilityToken, pass: chk.body.pass, body: "Fine lesson." });
    expect(pub.body.error).toBe("publications_disabled");

    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "DISABLE_NEW_PUBLICATIONS", on: false },
    });
    const pub2 = await publish({ eligibilityToken: elig.body.eligibilityToken, pass: chk.body.pass, body: "Fine lesson." });
    expect(pub2.status).toBe(200);

    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "HIDE_PUBLIC_EXPERIENCES", on: true },
    });
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(0);
    const mineFeed = await app.inject({ method: "GET", url: "/api/experiences/from-my-classes", headers: auth });
    expect((mineFeed.json() as { experiences: unknown[] }).experiences).toHaveLength(0);
  });

  it("repeated prohibited attempts at CHECK time suspend the account (§21), no text/link stored", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN, slur_or_dehumanizing: true } });
    const lessonId = await myLessonId();
    // Three high-confidence prohibited attempts — all at check, nothing stored.
    for (let i = 0; i < 3; i++) {
      const r = await check({ lessonId, body: `prohibited attempt ${i}` });
      expect(r.body.lane).toBe("blocked_serious");
    }
    expect(storedCount()).toBe(0);
    // Now the account is suspended from NEW publications.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    expect((await check({ lessonId, body: "a perfectly fine note now" })).body.error).toBe("temporarily_suspended");
    expect((await eligibility({ lessonId })).body.error).toBe("temporarily_suspended");
    // The abuse counter holds counts only — no body, no post id.
    const cols = app.ctx.db.prepare("PRAGMA table_info(abuse_counters)").all() as unknown as { name: string }[];
    expect(cols.map((c) => c.name).sort()).toEqual(["blocked_attempts", "honey_id", "last_blocked_at", "suspended_until"]);
  });

  it("admin routes reject non-admins", async () => {
    const nonAdminApp = buildApp({
      portalBaseUrl: app.ctx.config.portalBaseUrl,
      dbPath: join(tmp, "test2.db"),
      config: { adminStudentId: "9999" }, // mock student 88 ≠ 9999 → NOT admin
    });
    const login = await nonAdminApp.inject({
      method: "POST", url: "/api/auth/login",
      payload: { username: "s0088", password: "pw-good" },
    });
    const token = (login.json() as { session: { accessToken: string } }).session.accessToken;
    const res = await nonAdminApp.inject({
      method: "GET", url: "/api/admin/overview",
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(403);
    await nonAdminApp.close();
  });
});
