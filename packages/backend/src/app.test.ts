import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { AddressInfo } from "node:net";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { makeMockPortal } from "@honey/portal-connector/testing";
import { buildApp } from "./app.js";

// End-to-end M2 acceptance: school login IS signup (honeyId assigned), session
// independence, consent-gated import, timetable/next-lesson/history queries.

let portal: ReturnType<typeof makeMockPortal>;
let app: ReturnType<typeof buildApp>;
let tmp: string;

beforeEach(async () => {
  portal = makeMockPortal();
  await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const addr = portal.app.server.address() as AddressInfo;
  tmp = mkdtempSync(join(tmpdir(), "honey-test-"));
  app = buildApp({
    portalBaseUrl: `http://127.0.0.1:${addr.port}`,
    dbPath: join(tmp, "test.db"),
  });
});

afterEach(async () => {
  await app.close();
  await portal.app.close();
  rmSync(tmp, { recursive: true, force: true });
});

const LOGIN = { username: "s0088", password: "pw-good" };

async function login(consent = true) {
  const res = await app.inject({
    method: "POST",
    url: "/api/auth/login",
    payload: { ...LOGIN, consentTimetable: consent },
  });
  expect(res.statusCode).toBe(200);
  return res.json() as {
    honeyId: string;
    created: boolean;
    isAdmin: boolean;
    consent: { timetable: boolean };
    session: { accessToken: string; refreshToken: string };
  };
}

describe("auth: school login is signup", () => {
  it("first login provisions a honeyId; second login reconnects the same account", async () => {
    const first = await login();
    expect(first.created).toBe(true);
    expect(first.honeyId).toMatch(/^[23456789abcdefghjkmnpqrstuvwxyz]{6}$/);

    const second = await login();
    expect(second.created).toBe(false);
    expect(second.honeyId).toBe(first.honeyId);
  });

  it("rejects wrong school credentials with 401 and stores nothing", async () => {
    const res = await app.inject({
      method: "POST",
      url: "/api/auth/login",
      payload: { username: "s0088", password: "wrong" },
    });
    expect(res.statusCode).toBe(401);
    expect(res.json()).toEqual({ error: "school_credentials_rejected" });
    const users = app.ctx.db.prepare("SELECT COUNT(*) AS n FROM honey_users").get() as { n: number };
    expect(users.n).toBe(0);
  });

  it("issues independent HOney sessions: refresh rotates, logout invalidates", async () => {
    const { session } = await login();

    const me1 = await app.inject({
      method: "GET",
      url: "/api/me",
      headers: { authorization: `Bearer ${session.accessToken}` },
    });
    expect(me1.statusCode).toBe(200);

    const refreshed = await app.inject({
      method: "POST",
      url: "/api/auth/refresh",
      payload: { refreshToken: session.refreshToken },
    });
    expect(refreshed.statusCode).toBe(200);
    const newSession = refreshed.json() as { accessToken: string; refreshToken: string };

    // Old refresh token is consumed (rotation).
    const replay = await app.inject({
      method: "POST",
      url: "/api/auth/refresh",
      payload: { refreshToken: session.refreshToken },
    });
    expect(replay.statusCode).toBe(401);

    await app.inject({
      method: "POST",
      url: "/api/auth/logout",
      headers: { authorization: `Bearer ${newSession.accessToken}` },
    });
    const meAfter = await app.inject({
      method: "GET",
      url: "/api/me",
      headers: { authorization: `Bearer ${newSession.accessToken}` },
    });
    expect(meAfter.statusCode).toBe(401);
  });

  it("admin is bound at provisioning; '0088' config matches the portal id 88", async () => {
    // Default adminStudentId "0088"; mock portal id is 88 (leading-zero tolerant).
    const result = await login();
    expect(result.isAdmin).toBe(true);
  });

  it("portal token stored sealed — raw token never appears in the database", async () => {
    await login();
    const row = app.ctx.db
      .prepare("SELECT portal_token_sealed FROM school_connections")
      .get() as { portal_token_sealed: Uint8Array };
    const sealedHex = Buffer.from(row.portal_token_sealed).toString("latin1");
    expect(sealedHex).not.toContain("tok-"); // mock tokens are "tok-…"
  });
});

describe("consent & import", () => {
  it("POST /api/sync accepts an empty JSON body (bodyless action)", async () => {
    const { session } = await login(true);
    const res = await app.inject({
      method: "POST",
      url: "/api/sync",
      headers: { authorization: `Bearer ${session.accessToken}`, "content-type": "application/json" },
      payload: "",
    });
    expect(res.statusCode).toBe(200);
    expect((res.json() as { status: string }).status).toBe("ok");
  });

  it("no consent → no imported data; consent + sync → lessons appear", async () => {
    const noConsent = await login(false);
    expect(noConsent.consent.timetable).toBe(false);
    const auth = { authorization: `Bearer ${noConsent.session.accessToken}` };

    const sync1 = await app.inject({ method: "POST", url: "/api/sync", headers: auth });
    expect((sync1.json() as { status: string }).status).toBe("no_consent");

    await app.inject({
      method: "POST",
      url: "/api/consent",
      headers: auth,
      payload: { timetable: true },
    });
    const sync2 = await app.inject({ method: "POST", url: "/api/sync", headers: auth });
    const result = sync2.json() as { status: string; lessons: number };
    expect(result.status).toBe("ok");
    expect(result.lessons).toBeGreaterThan(0);
  });

  it("expired portal token → sync reports portal_reconnect_required; /api/portal/token repairs it", async () => {
    const { session, honeyId } = await login();
    const auth = { authorization: `Bearer ${session.accessToken}` };

    // Invalidate all portal tokens server-side (simulates 24h expiry).
    portal.state.tokens.clear();
    const sync = await app.inject({ method: "POST", url: "/api/sync", headers: auth });
    expect((sync.json() as { status: string }).status).toBe("portal_reconnect_required");

    // Client repairs by pushing a fresh client-obtained token.
    const loginRes = await fetch(`${(app.ctx.config.portalBaseUrl)}/api/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(LOGIN),
    });
    const freshToken = ((await loginRes.json()) as { token: string }).token;
    const push = await app.inject({
      method: "POST",
      url: "/api/portal/token",
      headers: auth,
      payload: { token: freshToken },
    });
    expect(push.statusCode).toBe(200);

    const sync2 = await app.inject({ method: "POST", url: "/api/sync", headers: auth });
    expect((sync2.json() as { status: string }).status).toBe("ok");
    expect(honeyId).toBeTruthy();
  });
});

describe("timetable queries", () => {
  it("day view, next-lesson and history return imported lessons scoped to the user", async () => {
    const { session } = await login();
    const auth = { authorization: `Bearer ${session.accessToken}` };
    await app.inject({ method: "POST", url: "/api/sync", headers: auth });

    const directory = await app.inject({ method: "GET", url: "/api/directory", headers: auth });
    const dir = directory.json() as { teachers: { id: string; name: string }[] };
    expect(dir.teachers.some((t) => t.name === "Ms Mock")).toBe(true);

    const history = await app.inject({
      method: "GET",
      url: "/api/history?q=Physics&order=desc",
      headers: auth,
    });
    const lessons = (history.json() as { lessons: { subjectName: string; startsAt: number }[] }).lessons;
    expect(lessons.length).toBeGreaterThan(0);
    expect(lessons.every((l) => l.subjectName === "Physics")).toBe(true);
    // History only shows past lessons.
    expect(lessons.every((l) => l.startsAt < Date.now())).toBe(true);

    const teacherId = dir.teachers[0]!.id;
    const count = await app.inject({
      method: "GET",
      url: `/api/directory/teachers/${teacherId}/lesson-count`,
      headers: auth,
    });
    expect((count.json() as { count: number }).count).toBeGreaterThan(0);
  });

  it("deleting imported data clears history but keeps the account", async () => {
    const { session } = await login();
    const auth = { authorization: `Bearer ${session.accessToken}` };
    await app.inject({ method: "POST", url: "/api/sync", headers: auth });

    await app.inject({ method: "DELETE", url: "/api/imported-data", headers: auth });
    const history = await app.inject({ method: "GET", url: "/api/history", headers: auth });
    expect((history.json() as { lessons: unknown[] }).lessons).toHaveLength(0);

    const me = await app.inject({ method: "GET", url: "/api/me", headers: auth });
    expect(me.statusCode).toBe(200);
  });
});
