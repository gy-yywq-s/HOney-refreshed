import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { AddressInfo } from "node:net";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { makeMockPortal } from "@honey/portal-connector/testing";
import { buildApp } from "../app.js";
import { EligibilityService } from "./eligibility.js";

// Standing on Core (spec §31.1): lesson targets need the account's exposure;
// standalone targets follow the admin's modes (verified / open / invite /
// closed) and frozen marks; dishes need an admin import. The opaque lesson
// id never equals the raw instance id.

let portal: ReturnType<typeof makeMockPortal>;
let app: ReturnType<typeof buildApp>;
let tmp: string;
let auth: { authorization: string };
let honeyId: string;

beforeEach(async () => {
  portal = makeMockPortal();
  await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const addr = portal.app.server.address() as AddressInfo;
  tmp = mkdtempSync(join(tmpdir(), "honey-elig-"));
  app = buildApp({
    portalBaseUrl: `http://127.0.0.1:${addr.port}`,
    dbPath: join(tmp, "core.db"),
    config: { adminStudentId: "88" },
    communityFetch: (async () => new Response(JSON.stringify({ ok: true }), { status: 200 })) as unknown as typeof fetch,
  });
  const res = await app.inject({ method: "POST", url: "/api/auth/login", payload: { username: "s0088", password: "pw-good" } });
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

describe("target resolution", () => {
  it("own lesson → opaque scope with canonical contexts; a foreign lesson is refused", async () => {
    const lessonId = await myLessonId();
    const ok = app.ctx.eligibility.resolveTarget(honeyId, lessonId);
    expect(ok.ok).toBe(true);
    if (!ok.ok) return;
    expect(ok.target.entityKey.startsWith("lesson:")).toBe(true);
    expect(ok.target.entityKey).not.toContain(lessonId);
    expect(ok.target.ctx.course).toBeTruthy();
    expect(ok.target.ctx.teacher).toBeTruthy();
    expect(ok.target.provenance).toBe("verified_lesson");
    expect(app.ctx.eligibility.resolveTarget(honeyId, "999999")).toEqual({ ok: false, error: "lesson_not_yours" });
    expect(app.ctx.eligibility.resolveTarget(honeyId)).toEqual({ ok: false, error: "target_required" });
  });

  it("a lesson that has not started yet is refused; the same lesson resolves once it has begun", async () => {
    const lessonId = await myLessonId();
    const row = app.ctx.db.prepare("SELECT starts_at FROM lesson_instances WHERE id = ?").get(lessonId) as { starts_at: number };
    // The seal key only shapes the opaque scope id, not the decision; the clock does.
    const before = new EligibilityService(app.ctx.db, app.ctx.entities, app.ctx.settings, Buffer.alloc(32, 7), () => row.starts_at - 60_000);
    expect(before.resolveTarget(honeyId, lessonId)).toEqual({ ok: false, error: "lesson_not_started" });
    const after = new EligibilityService(app.ctx.db, app.ctx.entities, app.ctx.settings, Buffer.alloc(32, 7), () => row.starts_at + 60_000);
    expect(after.resolveTarget(honeyId, lessonId).ok).toBe(true);
  });

  it("teacher with exposure → verified_retrospective; a dish needs an admin import and gets member provenance", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const t = app.ctx.eligibility.resolveTarget(honeyId, undefined, teacher.entity_key);
    expect(t.ok && t.target.provenance).toBe("verified_retrospective");
    expect(app.ctx.eligibility.resolveTarget(honeyId, undefined, "dish:d_unknown")).toEqual({ ok: false, error: "entity_unknown" });
    await app.inject({ method: "POST", url: "/api/admin/entities/import", headers: auth, payload: { items: [{ type: "dish", name: "麻婆豆腐" }] } });
    const dishes = await app.inject({ method: "GET", url: "/api/entities?type=dish", headers: auth });
    const dish = (dishes.json() as { entities: { entity_key: string }[] }).entities[0]!;
    const d = app.ctx.eligibility.resolveTarget(honeyId, undefined, dish.entity_key);
    expect(d.ok && d.target.provenance).toBe("verified_member");
  });

  it("closed mode refuses; invite mode admits only invited students; frozen entities refuse", async () => {
    const entities = await app.inject({ method: "GET", url: "/api/entities?type=teacher", headers: auth });
    const teacher = (entities.json() as { entities: { entity_key: string }[] }).entities[0]!;
    await app.inject({ method: "POST", url: "/api/admin/standalone-mode", headers: auth, payload: { scope: "type.teacher", mode: "closed" } });
    expect(app.ctx.eligibility.resolveTarget(honeyId, undefined, teacher.entity_key)).toEqual({ ok: false, error: "standalone_closed" });
    await app.inject({ method: "POST", url: "/api/admin/standalone-mode", headers: auth, payload: { scope: "type.teacher", mode: "invite" } });
    expect(app.ctx.eligibility.resolveTarget(honeyId, undefined, teacher.entity_key)).toEqual({ ok: false, error: "not_invited" });
    await app.inject({ method: "POST", url: "/api/admin/invite", headers: auth, payload: { entityKey: teacher.entity_key, studentId: "88" } });
    expect(app.ctx.eligibility.resolveTarget(honeyId, undefined, teacher.entity_key).ok).toBe(true);
    await app.inject({ method: "POST", url: "/api/admin/freeze-entity", headers: auth, payload: { entityKey: teacher.entity_key, frozen: true } });
    expect(app.ctx.eligibility.resolveTarget(honeyId, undefined, teacher.entity_key)).toEqual({ ok: false, error: "entity_frozen" });
    // A lesson whose teacher is frozen is refused too.
    expect(app.ctx.eligibility.resolveTarget(honeyId, await myLessonId())).toEqual({ ok: false, error: "entity_frozen" });
  });

  it("Core has no post table and no author lookup route", async () => {
    const tables = (app.ctx.db.prepare("SELECT name FROM sqlite_master WHERE type = 'table'").all() as { name: string }[]).map((t) => t.name);
    for (const t of ["experiences", "experience_associations", "reactions", "reports", "abuse_counters", "review_marks"]) expect(tables).not.toContain(t);
    expect((await app.inject({ method: "GET", url: "/api/experiences/feed", headers: auth })).statusCode).toBe(404);
    expect((await app.inject({ method: "POST", url: "/api/experiences/publish", payload: {} })).statusCode).toBe(404);
  });
});
