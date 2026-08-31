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

// M3 acceptance suite — maps onto App A §26.2 launch gates: serious content
// never publishes, fail-closed on outage/uncertainty, pass binding, no author
// fields, kill switches, one-per-lesson marks, raw-first browsing.

const CLEAN: LlmFeatures = {
  serious_allegation: false,
  targets_student: false,
  slur_or_dehumanizing: false,
  privacy_invasion: false,
  high_arousal: false,
  hearsay: false,
  targeted_profanity: false,
  injection_attempt: false,
  uncertain: false,
};

describe("policy engine (deterministic)", () => {
  const base = { lexical: [] as never[], entityType: "lesson", hasRating: false };

  it("ordinary negative opinion publishes", () => {
    expect(decide({ ...base, llm: { ...CLEAN } }).action).toBe("publish");
  });
  it("serious allegation / student target / privacy → blocked out of scope", () => {
    expect(decide({ ...base, llm: { ...CLEAN, serious_allegation: true } }).action).toBe("blocked_out_of_scope");
    expect(decide({ ...base, llm: { ...CLEAN, targets_student: true } }).action).toBe("blocked_out_of_scope");
    expect(decide({ ...base, llm: { ...CLEAN, privacy_invasion: true } }).action).toBe("blocked_out_of_scope");
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

async function settle(times = 8) {
  for (let i = 0; i < times; i++) await new Promise((r) => setImmediate(r));
}

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
    payload: { username: "s0088", password: "pw-good", consentTimetable: true },
  });
  const body = res.json() as { honeyId: string; session: { accessToken: string } };
  honeyId = body.honeyId;
  auth = { authorization: `Bearer ${body.session.accessToken}` };
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

async function submit(payload: Record<string, unknown>) {
  const res = await app.inject({ method: "POST", url: "/api/experiences", headers: auth, payload });
  return { status: res.statusCode, body: res.json() as Record<string, unknown> };
}

describe("publication pipeline", () => {
  it("clean lesson review publishes async, raw text verbatim, no author anywhere", async () => {
    const lessonId = await myLessonId();
    const text = "Honestly the pacing was way too fast — I was lost all lesson.";
    const r = await submit({ lessonId, body: text });
    expect(r.status).toBe(200);
    expect(r.body.status).toBe("pending"); // async: responds before moderation
    await settle();

    // Lesson posts are NOT queryable by raw lesson id (C1); browse the feed.
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const experiences = (feed.json() as { experiences: Record<string, unknown>[] }).experiences;
    expect(experiences).toHaveLength(1);
    expect(experiences[0]!.body).toBe(text); // raw-first: byte-for-byte
    // The public record exposes no raw lesson id and no exact timestamp (C1/S5).
    expect(experiences[0]!.lesson_id).toBeUndefined();
    expect(experiences[0]!.published_at).toBeUndefined();
    expect(typeof experiences[0]!.publishedDay).toBe("number");
    expect(experiences[0]!.provenance).toBe("verified_lesson");
    // No author-ish field in the response…
    const keys = Object.keys(experiences[0]!);
    expect(keys.some((k) => /honey|author|user|student/i.test(k))).toBe(false);
    // …and no author column in storage (launch gate: verified absence).
    const cols = app.ctx.db.prepare("PRAGMA table_info(experiences)").all() as unknown as { name: string }[];
    expect(cols.some((c) => /honey|author|user|student/i.test(c.name))).toBe(false);
  });

  it("serious content never publishes and its text is not persisted", async () => {
    app.ctx.experiences.llmRunner = async () => ({
      ok: true,
      features: { ...CLEAN, serious_allegation: true },
    });
    const lessonId = await myLessonId();
    const r = await submit({ lessonId, body: "Mr X assaulted someone last week, spread the word." });
    const key = r.body.ownershipKey as string;
    await settle();

    const mine = await app.inject({
      method: "POST",
      url: "/api/experiences/mine",
      headers: auth,
      payload: { keys: [key] },
    });
    const rows = (mine.json() as { experiences: { status: string; body: string | null }[] }).experiences;
    expect(rows[0]!.status).toBe("blocked");
    expect(rows[0]!.body).toBeNull(); // rejected text not persisted
    const stored = app.ctx.db.prepare("SELECT body FROM experiences").all() as unknown as { body: string | null }[];
    expect(stored.every((s) => s.body === null || !s.body.includes("assaulted"))).toBe(true);
    // Mark released → the user can write a compliant review instead.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    const retry = await submit({ lessonId, body: "The lesson felt rushed." });
    expect(retry.status).toBe(200);
  });

  it("lexical threat blocks WITHOUT calling the LLM", async () => {
    let llmCalls = 0;
    app.ctx.experiences.llmRunner = async () => {
      llmCalls++;
      return { ok: true, features: { ...CLEAN } };
    };
    const lessonId = await myLessonId();
    const r = await submit({ lessonId, body: "I will kill you Mr Zhang" });
    await settle();
    const mine = await app.inject({
      method: "POST", url: "/api/experiences/mine", headers: auth,
      payload: { keys: [r.body.ownershipKey] },
    });
    expect((mine.json() as { experiences: { status: string }[] }).experiences[0]!.status).toBe("blocked");
    expect(llmCalls).toBe(0);
  });

  it("LLM outage fails closed (never publish-first)", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ok: false });
    const lessonId = await myLessonId();
    const r = await submit({ lessonId, body: "Perfectly ordinary note about the lesson." });
    await settle();
    const mine = await app.inject({
      method: "POST", url: "/api/experiences/mine", headers: auth,
      payload: { keys: [r.body.ownershipKey] },
    });
    expect((mine.json() as { experiences: { status: string }[] }).experiences[0]!.status).toBe("failed_closed");
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(0);
  });

  it("high-arousal → cooldown; reconfirm gated until window passes; then publishes", async () => {
    app.ctx.experiences.llmRunner = async () => ({
      ok: true,
      features: { ...CLEAN, high_arousal: true },
    });
    const lessonId = await myLessonId();
    const r = await submit({ lessonId, body: "ABSOLUTELY FURIOUS about how this lesson went!!!" });
    const key = r.body.ownershipKey as string;
    await settle();

    const early = await app.inject({
      method: "POST", url: "/api/experiences/reconfirm", headers: auth,
      payload: { ownershipKey: key },
    });
    expect(early.statusCode).toBe(422);
    expect((early.json() as { error: string }).error).toBe("cooldown_active");

    // Window elapses (direct clock nudge in storage).
    app.ctx.db.prepare("UPDATE experiences SET cooldown_until = ? WHERE ownership_hash IS NOT NULL").run(Date.now() - 1000);
    const late = await app.inject({
      method: "POST", url: "/api/experiences/reconfirm", headers: auth,
      payload: { ownershipKey: key },
    });
    expect(late.statusCode).toBe(200);
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(1);
  });

  it("one review per lesson; revoke frees the slot", async () => {
    const lessonId = await myLessonId();
    const first = await submit({ lessonId, body: "First take." });
    await settle();
    const dup = await submit({ lessonId, body: "Second take." });
    expect(dup.status).toBe(422);
    expect(dup.body.error).toBe("already_reviewed");

    const revoke = await app.inject({
      method: "POST", url: "/api/experiences/revoke", headers: auth,
      payload: { ownershipKey: first.body.ownershipKey },
    });
    expect(revoke.statusCode).toBe(200);
    const again = await submit({ lessonId, body: "Recon­sidered take." });
    expect(again.status).toBe(200);
  });
});

describe("standalone entities & eligibility", () => {
  it("verified mode: teacher review allowed with exposure; dish needs admin import; rating rules hold", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const tr = await submit({ entityKey: teacher.entity_key, body: "Very patient across a whole term." });
    expect(tr.status).toBe(200);
    await settle();

    // Rating on a teacher is refused outright.
    const rated = await submit({ entityKey: teacher.entity_key, body: "5 stars", rating: 5 });
    expect(rated.body.error).toBe("rating_not_allowed");

    // Dish: admin imports it; rating 1–5 allowed.
    await app.inject({
      method: "POST", url: "/api/admin/entities/import", headers: auth,
      payload: { items: [{ type: "dish", name: "麻婆豆腐" }] },
    });
    const dishes = await app.inject({ method: "GET", url: "/api/entities?type=dish", headers: auth });
    const dish = (dishes.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const dr = await submit({ entityKey: dish.entity_key, body: "Solid, a bit oily.", rating: 4 });
    expect(dr.status).toBe(200);
  });

  it("closed mode blocks everyone; invite mode admits only invited students", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;

    await app.inject({
      method: "POST", url: "/api/admin/standalone-mode", headers: auth,
      payload: { scope: "type.teacher", mode: "closed" },
    });
    expect((await submit({ entityKey: teacher.entity_key, body: "x" })).body.error).toBe("standalone_closed");

    await app.inject({
      method: "POST", url: "/api/admin/standalone-mode", headers: auth,
      payload: { scope: "type.teacher", mode: "invite" },
    });
    expect((await submit({ entityKey: teacher.entity_key, body: "x" })).body.error).toBe("not_invited");

    await app.inject({
      method: "POST", url: "/api/admin/invite", headers: auth,
      payload: { entityKey: teacher.entity_key, studentId: "88" },
    });
    expect((await submit({ entityKey: teacher.entity_key, body: "Good teacher, invited take." })).status).toBe(200);
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

describe("reactions, kill switches, admin gate", () => {
  it("reaction dedup + change + small-cohort hiding", async () => {
    const lessonId = await myLessonId();
    const r = await submit({ lessonId, body: "Useful lesson overall." });
    await settle();
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    const expId = (feed.json() as { experiences: { id: string }[] }).experiences[0]!.id;

    await app.inject({ method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: 1 } });
    await app.inject({ method: "POST", url: `/api/experiences/${expId}/react`, headers: auth, payload: { value: -1 } });
    let counts = app.ctx.db.prepare("SELECT COUNT(*) AS n FROM reactions").get() as unknown as { n: number };
    expect(counts.n).toBe(1); // one active reaction per user, value changed

    // Hide counts below threshold.
    await app.inject({
      method: "POST", url: "/api/admin/reaction-min-count", headers: auth, payload: { minCount: 5 },
    });
    const hidden = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((hidden.json() as { experiences: { reactions: unknown }[] }).experiences[0]!.reactions).toBeNull();
    expect(r.status).toBe(200);
  });

  it("kill switches: publications off; feed hidden", async () => {
    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "DISABLE_NEW_PUBLICATIONS", on: true },
    });
    const lessonId = await myLessonId();
    expect((await submit({ lessonId, body: "x" })).body.error).toBe("publications_disabled");
    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "DISABLE_NEW_PUBLICATIONS", on: false },
    });
    await submit({ lessonId, body: "Fine lesson." });
    await settle();

    await app.inject({
      method: "POST", url: "/api/admin/kill-switch", headers: auth,
      payload: { name: "HIDE_PUBLIC_EXPERIENCES", on: true },
    });
    const feed = await app.inject({ method: "GET", url: "/api/experiences", headers: auth });
    expect((feed.json() as { experiences: unknown[] }).experiences).toHaveLength(0);
  });

  it("repeated prohibited attempts suspend the account (§21), no text/link stored", async () => {
    app.ctx.experiences.llmRunner = async () => ({ ...({ ok: true } as const), features: { ...CLEAN, slur_or_dehumanizing: true } });
    const lessonId = await myLessonId();
    // Three high-confidence prohibited attempts (each blocked + text purged).
    for (let i = 0; i < 3; i++) {
      const r = await submit({ lessonId, body: `prohibited attempt ${i}` });
      // First is accepted for processing then blocked; dedup mark is released so
      // the same lesson can be retried (that is what lets abuse accumulate).
      await settle();
      expect([200, 422]).toContain(r.status);
    }
    // Now the account is suspended from NEW publications.
    app.ctx.experiences.llmRunner = async () => ({ ok: true, features: { ...CLEAN } });
    const blocked = await submit({ lessonId, body: "a perfectly fine note now" });
    expect(blocked.body.error).toBe("temporarily_suspended");
    // The abuse counter holds counts only — no body, no post id.
    const cols = app.ctx.db.prepare("PRAGMA table_info(abuse_counters)").all() as unknown as { name: string }[];
    expect(cols.map((c) => c.name).sort()).toEqual(["blocked_attempts", "honey_id", "last_blocked_at", "suspended_until"]);
  });

  it("admin routes reject non-admins", async () => {
    const nonAdminApp = buildApp({
      portalBaseUrl: app.ctx.config.portalBaseUrl,
      dbPath: join(tmp, "test2.db"),
      config: { adminStudentId: "0088" }, // mock student is 88 → NOT admin
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
