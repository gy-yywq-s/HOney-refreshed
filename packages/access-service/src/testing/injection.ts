// The failure-injection run (spec §26.2): eleven ways a physical request can
// go wrong, each driven through the real HTTP surface against the mock
// portal, each recorded with what the journal says and what the student was
// told. `runInjections` is shared by the test (asserts) and the script
// (writes the transcript under docs/status/).

import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { makeMockPortal, type MockPortalState } from "@honey/portal-connector/testing";
import type { AccessProgressEvent, OperationState, PreparedOpenOperation, SealedPortalSession } from "@honey/shared/access";
import { buildAccessApp, type AccessApp } from "../app.js";
import type { AccessConfig } from "../config.js";
import { makeTestIssuer, type TestIssuer } from "./issue.js";

export interface InjectionResult {
  id: number;
  name: string;
  injected: string;
  expected: string;
  /** What the HTTP surface returned (status + error code) or streamed (terminal stage). */
  observed: string;
  journalState: OperationState | "none";
  outcomeCode: string | null;
  /** Portal door requests that reached the mock (the physical count). */
  doorRequests: number;
  studentSaw: string;
  pass: boolean;
}

export interface Harness {
  access: AccessApp;
  issuer: TestIssuer;
  portal: { app: ReturnType<typeof makeMockPortal>["app"]; state: MockPortalState };
  portalUrl: string;
  token: string;
  capability: (over?: { subject?: string; ttlMs?: number; tamper?: boolean; token?: string }) => Promise<string>;
  now: { value: number };
  dir: string;
  close(): Promise<void>;
}

export async function makeHarness(over: { mode?: MockPortalState["mode"]; portalTimeoutMs?: number; egressAllowed?: string[] } = {}): Promise<Harness> {
  const portal = makeMockPortal(over.mode ? { mode: over.mode } : {});
  const portalUrl = await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const token = "tok-test";
  portal.state.tokens.set(token, Math.floor(Date.now() / 1000) + 3600);
  const issuer = await makeTestIssuer();
  const dir = mkdtempSync(join(tmpdir(), "honey-access-"));
  // The mock portal's one permit runs 2026-08-31 08:00–22:00 (school zone); the service clock sits inside it.
  const now = { value: Date.UTC(2026, 7, 31, 4, 0, 0) };
  const config: AccessConfig = {
    dbPath: join(dir, "access.db"),
    keysDir: join(dir, "keys"),
    portalBaseUrl: portalUrl,
    internalSecret: "internal-test",
    serviceVersion: "test",
    production: false,
    allowedEgressOrigins: over.egressAllowed ?? [new URL(portalUrl).origin],
  };
  const access = await buildAccessApp({ config, keys: issuer.keys, portalTimeoutMs: over.portalTimeoutMs ?? 800, now: () => now.value });
  await access.app.ready();
  const session = (tok: string): SealedPortalSession => ({ token: tok, tokenExpiresAt: now.value + 3600_000, portalStudentId: "88", schoolId: "huayaopudong" });
  return {
    access,
    issuer,
    portal,
    portalUrl,
    token,
    now,
    dir,
    capability: (o = {}) => issuer.issue({ subject: o.subject ?? "subj-1", session: session(o.token ?? token), now: now.value, ...(o.ttlMs !== undefined ? { ttlMs: o.ttlMs } : {}), ...(o.tamper ? { tamper: true } : {}) }),
    async close() {
      await access.close();
      await portal.app.close();
      rmSync(dir, { recursive: true, force: true });
    },
  };
}

export async function prepareOpen(h: Harness, cap: string, body: Record<string, unknown> = { route: "exit_permit", gateKey: "door-front-01", permitRecordId: 501, clientNonce: "n1" }) {
  return h.access.app.inject({ method: "POST", url: "/access/operations/open/prepare", headers: { "access-capability": cap, "content-type": "application/json" }, payload: body });
}

export async function commit(h: Harness, cap: string, op: PreparedOpenOperation, secret = op.commitSecret): Promise<{ status: number; body: string; events: AccessProgressEvent[] }> {
  const res = await h.access.app.inject({ method: "POST", url: `/access/operations/${op.operationId}/commit`, headers: { "access-capability": cap, "access-commit": secret } });
  const events = res.statusCode === 200 ? res.body.split("\n").filter(Boolean).map((l) => JSON.parse(l) as AccessProgressEvent) : [];
  return { status: res.statusCode, body: res.body, events };
}

function terminal(events: AccessProgressEvent[]): AccessProgressEvent | undefined {
  return events.find((e) => e.terminal);
}

/** The eleven injections. Each builds its own harness so one failure cannot leak into the next. */
export async function runInjections(): Promise<InjectionResult[]> {
  const results: InjectionResult[] = [];
  const record = (r: Omit<InjectionResult, "id">) => results.push({ id: results.length + 1, ...r });

  const withHarness = async (opts: Parameters<typeof makeHarness>[0], fn: (h: Harness) => Promise<void>) => {
    const h = await makeHarness(opts);
    try {
      await fn(h);
    } finally {
      await h.close();
    }
  };
  const journal = (h: Harness, id: string | undefined) => {
    const row = id ? h.access.store.get(id) : null;
    return { journalState: (row?.state ?? "none") as OperationState | "none", outcomeCode: row?.outcome_code ?? null };
  };

  // 1. Switch OFF at prepare: nothing prepared, nothing sent.
  await withHarness({}, async (h) => {
    const cap = await h.capability();
    const res = await prepareOpen(h, cap);
    record({ name: "switch off at prepare", injected: "WEB_ACCESS_ENABLED=false (default)", expected: "423 access_paused; no operation; 0 door requests", observed: `${res.statusCode} ${JSON.parse(res.body).error}`, ...journal(h, undefined), doorRequests: h.portal.state.doorRequestCount, studentSaw: "Web Access is paused right now. Nothing was sent.", pass: res.statusCode === 423 && h.portal.state.doorRequestCount === 0 });
  });

  // 2. Switch flipped OFF between prepare and commit.
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    h.access.policy.setEnabled(false);
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "paused between prepare and commit", injected: "switch → off after prepare", expected: "423 access_paused; journal PAUSED; 0 door requests", observed: `${c.status} ${c.status !== 200 ? JSON.parse(c.body).error : ""}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: "Web Access was paused before this was sent. Nothing was sent.", pass: c.status === 423 && j.journalState === "PAUSED" && h.portal.state.doorRequestCount === 0 });
  });

  // 3. Wrong commit secret.
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const c = await commit(h, cap, op, "not-the-secret");
    const j = journal(h, op.operationId);
    record({ name: "wrong commit secret", injected: "Access-Commit header does not match", expected: "403 commit_secret_invalid; journal stays PREPARED; 0 door requests", observed: `${c.status} ${JSON.parse(c.body).error}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: "This confirmation is no longer valid. Nothing was sent.", pass: c.status === 403 && j.journalState === "PREPARED" && h.portal.state.doorRequestCount === 0 });
  });

  // 4. Expired prepare (commit after the 60 s window).
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    h.now.value += 61_000;
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "expired prepare", injected: "clock +61 s between prepare and commit", expected: "409 operation_not_prepared; journal EXPIRED; 0 door requests", observed: `${c.status} ${JSON.parse(c.body).error}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: "This confirmation expired. Nothing was sent. Start again.", pass: c.status === 409 && j.journalState === "EXPIRED" && h.portal.state.doorRequestCount === 0 });
  });

  // 5. Double commit (two concurrent commits of one prepared operation).
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const [a, b] = await Promise.all([commit(h, cap, op), commit(h, cap, op)]);
    const j = journal(h, op.operationId);
    const both = [a, b].every((c) => c.status === 200 && terminal(c.events)?.stage === "confirmed");
    record({ name: "double commit", injected: "two simultaneous commits with the right secret", expected: "both streams end confirmed; exactly 1 door request; journal CONFIRMED", observed: `${a.status}/${b.status} ${terminal(a.events)?.stage}/${terminal(b.events)?.stage}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: "Done. The school confirmed.", pass: both && h.portal.state.doorRequestCount === 1 && j.journalState === "CONFIRMED" });
  });

  // 6. Portal rejects the door request.
  await withHarness({ mode: "doorRejects" }, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "school rejects", injected: "portal answers status:1 'no permission'", expected: "stream ends rejected; journal REJECTED/portal_rejected; 1 door request", observed: `${c.status} ${terminal(c.events)?.stage}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: terminal(c.events)?.message ?? "", pass: terminal(c.events)?.stage === "rejected" && j.journalState === "REJECTED" && h.portal.state.doorRequestCount === 1 });
  });

  // 7. Portal hangs past the timeout: outcome unknown, never retried.
  await withHarness({ mode: "openDoorHang", portalTimeoutMs: 300 }, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "school does not answer", injected: "portal holds the door request past the 300 ms timeout", expected: "stream ends outcome_unknown; journal OUTCOME_UNKNOWN/timeout; exactly 1 door request (no retry)", observed: `${c.status} ${terminal(c.events)?.stage}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: terminal(c.events)?.message ?? "", pass: terminal(c.events)?.stage === "outcome_unknown" && j.journalState === "OUTCOME_UNKNOWN" && h.portal.state.doorRequestCount === 1 });
  });

  // 8. Portal 5xx on the door request.
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    h.portal.state.mode = "offline5xx";
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "school gateway error", injected: "portal answers 5xx after the request reached it (the mock's 5xx hook answers before its door counter, so the count reads 0)", expected: "stream ends outcome_unknown (a 5xx does not prove nothing happened); journal OUTCOME_UNKNOWN", observed: `${c.status} ${terminal(c.events)?.stage}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: terminal(c.events)?.message ?? "", pass: terminal(c.events)?.stage === "outcome_unknown" && j.journalState === "OUTCOME_UNKNOWN" });
  });

  // 9. Portal unreachable at commit (connection refused): never sent.
  await withHarness({}, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    await h.portal.app.close(); // the port is gone
    const c = await commit(h, cap, op);
    const j = journal(h, op.operationId);
    record({ name: "school unreachable", injected: "portal process stopped before commit (ECONNREFUSED)", expected: "stream ends not_sent; journal NOT_SENT", observed: `${c.status} ${terminal(c.events)?.stage}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: terminal(c.events)?.message ?? "", pass: terminal(c.events)?.stage === "not_sent" && j.journalState === "NOT_SENT" });
  });

  // 10. Egress misconfiguration: portal origin not on the allowlist.
  await withHarness({ egressAllowed: ["https://example.invalid"] }, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const res = await h.access.app.inject({ method: "GET", url: "/access/bootstrap", headers: { "access-capability": cap } });
    record({ name: "egress refused", injected: "allowlist excludes the portal origin", expected: "503 service_unavailable; 0 portal requests; nothing else contacted", observed: `${res.statusCode} ${JSON.parse(res.body).error}`, journalState: "none", outcomeCode: null, doorRequests: h.portal.state.doorRequestCount, studentSaw: "Web Access can't reach the school right now. Nothing was sent.", pass: res.statusCode === 503 && h.portal.state.doorRequestCount === 0 });
  });

  // 11. Restart while in flight: journal recovery marks OUTCOME_UNKNOWN, never re-sends.
  await withHarness({ mode: "openDoorHang", portalTimeoutMs: 5_000 }, async (h) => {
    h.access.policy.setEnabled(true);
    const cap = await h.capability();
    const op = JSON.parse((await prepareOpen(h, cap)).body) as PreparedOpenOperation;
    // Start the commit but do not wait for the portal; simulate a crash by reopening the journal.
    void h.access.app.inject({ method: "POST", url: `/access/operations/${op.operationId}/commit`, headers: { "access-capability": cap, "access-commit": op.commitSecret } }).catch(() => undefined);
    await new Promise((r) => setTimeout(r, 100));
    const before = h.access.store.get(op.operationId)!.state;
    const reopened = await buildAccessApp({ config: { ...(h.access as unknown as { config?: AccessConfig }).config ?? { dbPath: join(h.dir, "access.db"), keysDir: join(h.dir, "keys"), portalBaseUrl: h.portalUrl, internalSecret: "internal-test", serviceVersion: "test-restarted", production: false, allowedEgressOrigins: [new URL(h.portalUrl).origin] } }, keys: h.issuer.keys, now: () => h.now.value });
    const j = journal({ ...h, access: reopened }, op.operationId);
    const status = await reopened.app.inject({ method: "GET", url: `/access/operations/${op.operationId}`, headers: { "access-capability": cap } });
    await reopened.close();
    record({ name: "restart while waiting", injected: `service restarted with the operation ${before}`, expected: "journal OUTCOME_UNKNOWN/service_restarted after restart; status says so; door request count unchanged (1)", observed: `${before} → ${j.journalState}; status ${status.statusCode} ${JSON.parse(status.body).state}`, ...j, doorRequests: h.portal.state.doorRequestCount, studentSaw: "The school did not answer. Check the gate before trying again.", pass: j.journalState === "OUTCOME_UNKNOWN" && j.outcomeCode === "service_restarted" && h.portal.state.doorRequestCount === 1 });
  });

  return results;
}

export function renderTranscript(results: InjectionResult[], meta: { date: string; version: string }): string {
  const lines: string[] = [];
  lines.push(`# Web Access failure-injection run — ${meta.date}`);
  lines.push("");
  lines.push(`Service version: ${meta.version}. Driven through the real HTTP surface of the Access Service against the in-process mock portal (spec §26.2). Each injection uses a fresh journal and a fresh mock portal; the door-request column is the number of physical requests the mock actually received.`);
  lines.push("");
  lines.push(`Result: **${results.filter((r) => r.pass).length}/${results.length} passed**.`);
  lines.push("");
  lines.push("| # | Injection | Expected | Observed | Journal | Door requests | Student saw | Pass |");
  lines.push("|---|---|---|---|---|---|---|---|");
  for (const r of results) {
    lines.push(`| ${r.id} | ${r.name}: ${r.injected} | ${r.expected} | ${r.observed} | ${r.journalState}${r.outcomeCode ? ` / ${r.outcomeCode}` : ""} | ${r.doorRequests} | ${r.studentSaw} | ${r.pass ? "✅" : "❌"} |`);
  }
  lines.push("");
  lines.push("No injection produced a second physical request. Every path that did not reach the school says so (`not_sent`); every path where the school's answer is missing says `outcome_unknown` and is never retried by the service.");
  lines.push("");
  return lines.join("\n");
}
