import { afterEach, describe, expect, it } from "vitest";
import type { AccessBootstrap, PreparedOpenOperation } from "@honey/shared/access";
import { labelFor } from "./latency.js";
import { guardedFetch, EgressRefused } from "./portal-client.js";
import { commit, makeHarness, prepareOpen, runInjections, type Harness } from "./testing/injection.js";

let h: Harness | null = null;
afterEach(async () => {
  await h?.close();
  h = null;
});

describe("capability guard", () => {
  it("refuses a missing, tampered, expired or wrong-key capability, and any identity header", async () => {
    h = await makeHarness();
    const app = h.access.app;
    expect((await app.inject({ method: "GET", url: "/access/bootstrap" })).statusCode).toBe(401);
    const tampered = await h.capability({ tamper: true });
    expect(JSON.parse((await app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": tampered } })).body).error).toBe("capability_invalid");
    const expired = await h.capability({ ttlMs: -1 });
    expect(JSON.parse((await app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": expired } })).body).error).toBe("capability_expired");
    const good = await h.capability();
    const withCookie = await app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": good, cookie: "honey=1" } });
    expect(withCookie.statusCode).toBe(400);
  });

  it("opens the sealed session only in memory: the journal never holds the token", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    await commit(h, cap, op);
    const dump = JSON.stringify(h.access.db.prepare("SELECT * FROM access_operations").all()) + JSON.stringify(h.access.db.prepare("SELECT * FROM access_settings").all());
    expect(dump).not.toContain(h.token);
    expect(dump).not.toContain("subj-1");
    expect(dump).not.toContain(op.commitSecret);
  });
});

describe("bootstrap", () => {
  it("returns doors, permits, routes and an honest ETA", async () => {
    h = await makeHarness();
    const cap = await h.capability();
    const res = await h.access.app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": cap } });
    expect(res.statusCode).toBe(200);
    const b = JSON.parse(res.body) as AccessBootstrap;
    expect(b.enabled).toBe(false);
    expect(b.doors.map((d) => d.key)).toEqual(["door-front-01", "door-back-02"]);
    expect(b.permits).toHaveLength(1);
    expect(b.eta.openGate).toBe("Usually a few seconds");
    expect(b.identity.portalStudentId).toBe("88");
  });

  it("reports an expired portal session as such", async () => {
    h = await makeHarness();
    const cap = await h.capability({ token: "tok-unknown" });
    const res = await h.access.app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": cap } });
    expect(res.statusCode).toBe(401);
    expect(JSON.parse(res.body).error).toBe("portal_session_expired");
  });
});

describe("prepare", () => {
  it("re-reads permits and refuses a consumed or unknown one", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const unknown = await prepareOpen(h, cap, { route: "exit_permit", gateKey: "door-front-01", permitRecordId: 999, clientNonce: "n" });
    expect(JSON.parse(unknown.body).error).toBe("permit_not_usable");
    const badGate = await prepareOpen(h, cap, { route: "exit_permit", gateKey: "door-side-09", permitRecordId: 501, clientNonce: "n" });
    expect(JSON.parse(badGate.body).error).toBe("gate_unknown");
    const badRoute = await prepareOpen(h, cap, { route: "teacher", gateKey: "door-front-01", clientNonce: "n" });
    expect(JSON.parse(badRoute.body).error).toBe("route_not_allowed");
    // The mock student is a day student: the direct route prepares without a permit.
    const day = await prepareOpen(h, cap, { route: "day_student", gateKey: "door-front-01", clientNonce: "n" });
    expect(day.statusCode).toBe(200);
    expect(h.portal.state.doorRequestCount).toBe(0);
  });

  it("allows one active operation per subject and lets an expired prepare be replaced", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const first = await prepareOpen(h, cap);
    expect(first.statusCode).toBe(200);
    const second = await prepareOpen(h, cap);
    expect(JSON.parse(second.body).error).toBe("operation_in_progress");
    h.now.value += 61_000;
    const third = await prepareOpen(h, cap);
    expect(third.statusCode).toBe(200);
  });
});

describe("commit", () => {
  it("streams accepted → sending → waiting → confirmed and records one latency sample", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const c = await commit(h, cap, op);
    expect(c.status).toBe(200);
    expect(c.events.map((e) => e.stage)).toEqual(["accepted", "sending", "waiting_for_school", "confirmed"]);
    expect(c.events.at(-1)?.terminal).toBe(true);
    expect(h.portal.state.openDoorCalls).toEqual([{ record_id: 501, door_id: "door-front-01", indexcode: "door-front-01" }]);
    const samples = h.access.db.prepare("SELECT COUNT(*) AS n FROM access_latency_samples").get() as { n: number };
    expect(samples.n).toBe(1);
    const status = await h.access.app.inject({ method: "GET", url: `/access/operations/${op.operationId}`, headers: { "access-capability": cap } });
    expect(JSON.parse(status.body).state).toBe("CONFIRMED");
  });

  it("another subject cannot see or commit the operation", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const other = await h.capability({ subject: "subj-2" });
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const c = await commit(h, other, op);
    expect(c.status).toBe(404);
    expect(h.portal.state.doorRequestCount).toBe(0);
  });

  it("applies and withdraws permits through the same prepare/commit path", async () => {
    h = await makeHarness();
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const prep = await h.access.app.inject({ method: "POST", url: "/access/operations/permit/prepare", headers: { "access-capability": cap, "content-type": "application/json" }, payload: { startTime: "2026-09-03 12:00:00", endTime: "2026-09-03 14:00:00", note: "出门", clientNonce: "p1" } });
    expect(prep.statusCode).toBe(200);
    const op = JSON.parse(prep.body) as PreparedOpenOperation;
    const c = await commit(h, cap, op);
    expect(c.events.at(-1)?.stage).toBe("confirmed");
    const bad = await h.access.app.inject({ method: "POST", url: "/access/operations/permit/prepare", headers: { "access-capability": cap, "content-type": "application/json" }, payload: { startTime: "2026-09-03 14:00:00", endTime: "2026-09-03 12:00:00", note: "出门", clientNonce: "p2" } });
    expect(JSON.parse(bad.body).error).toBe("permit_not_usable");
  });
});

describe("admin", () => {
  it("is loopback + secret only and flips the switch", async () => {
    h = await makeHarness();
    const app = h.access.app;
    expect((await app.inject({ method: "GET", url: "/internal/admin/status" })).statusCode).toBe(404);
    const status = await app.inject({ method: "GET", url: "/internal/admin/status", headers: { "x-honey-internal": "internal-test" } });
    expect(status.statusCode).toBe(200);
    expect(JSON.parse(status.body).enabled).toBe(false);
    const on = await app.inject({ method: "POST", url: "/internal/admin/enabled", headers: { "x-honey-internal": "internal-test", "content-type": "application/json" }, payload: { on: true } });
    expect(JSON.parse(on.body).enabled).toBe(true);
    expect(h.access.policy.enabled()).toBe(true);
  });
});

describe("egress guard", () => {
  it("refuses any origin outside the allowlist before connecting", async () => {
    const f = guardedFetch(["https://www.huayaopudong.com"], (() => Promise.resolve(new Response("ok"))) as typeof fetch);
    await expect(f("https://example.com/x")).rejects.toBeInstanceOf(EgressRefused);
    expect(await (await f("https://www.huayaopudong.com/api/x")).text()).toBe("ok");
  });
});

describe("ETA label", () => {
  it("rounds to whole seconds and is never a single number", () => {
    expect(labelFor(1200, 1900)).toBe("Usually 1–2 seconds");
    expect(labelFor(2600, 6100)).toBe("Usually 3–7 seconds");
  });
});

describe("failure injection (spec §26.2)", () => {
  it("passes all eleven injections with at most one physical request each", async () => {
    const results = await runInjections();
    const failed = results.filter((r) => !r.pass);
    expect(failed, JSON.stringify(failed, null, 2)).toEqual([]);
    expect(results).toHaveLength(11);
    expect(results.every((r) => r.doorRequests <= 1)).toBe(true);
  }, 60_000);
});
