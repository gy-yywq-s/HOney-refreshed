import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { AddressInfo } from "node:net";
import type { AuthSession, StoredCredentials } from "@honey/shared";
import { HOneyPortalConnector } from "./connector.js";
import type { CredentialVault } from "./coordinator.js";
import { isPortalError } from "./errors.js";
import { makeMockPortal, type MockPortalState } from "./testing/mockPortal.js";

// Acceptance tests derived from connector-analysis doc 07 (the legacy-gap
// corrections): silent recovery, single-flight login, offline no-signout,
// invalid-credentials purge, 5xx session preservation, door-open no-retry.

class MemoryVault implements CredentialVault {
  session: AuthSession | null = null;
  creds: StoredCredentials | null = null;
  loadSessionCalls = 0;

  async loadSession() {
    this.loadSessionCalls++;
    return this.session;
  }
  async saveSession(s: AuthSession) {
    this.session = s;
  }
  async deleteSession() {
    this.session = null;
  }
  async loadAuthorizedCredentialsSilently() {
    return this.creds;
  }
  async deleteCredentials() {
    this.creds = null;
  }
}

let portal: ReturnType<typeof makeMockPortal>;
let baseUrl: string;
let state: MockPortalState;

beforeEach(async () => {
  portal = makeMockPortal();
  state = portal.state;
  await portal.app.listen({ port: 0, host: "127.0.0.1" });
  const addr = portal.app.server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${addr.port}`;
});

afterEach(async () => {
  await portal.app.close();
});

function connectorWith(vault: MemoryVault, timeoutMs = 3_000) {
  return new HOneyPortalConnector({ baseUrl, vault, timeoutMs });
}

const GOOD: StoredCredentials = { username: "s0088", password: "pw-good" };

describe("PortalSessionCoordinator", () => {
  it("expired token → one silent re-login, then safe reads replay (zero manual login)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    // Simulate a stale saved session with an unknown/expired token.
    vault.session = { token: "stale-token", expiresAt: new Date(Date.now() + 3_600_000), studentId: "88" };

    const c = connectorWith(vault);
    const permits = await c.getPermits();
    expect(permits).toHaveLength(1);
    expect(state.loginCount).toBe(1); // exactly one silent POST /api/login
    expect(vault.session?.token).not.toBe("stale-token"); // atomically replaced
  });

  it("20 concurrent expired reads → exactly one POST /api/login (single-flight)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    vault.session = { token: "stale", expiresAt: new Date(Date.now() + 3_600_000), studentId: "88" };

    const c = connectorWith(vault);
    const results = await Promise.all(Array.from({ length: 20 }, () => c.getPermits()));
    expect(results.every((r) => r.length === 1)).toBe(true);
    expect(state.loginCount).toBe(1);
  });

  it("offline portal at startup → temporarilyUnavailable, session & credentials preserved", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    vault.session = { token: "t", expiresAt: new Date(Date.now() - 1000), studentId: "88" };
    state.mode = "offline5xx";

    const c = connectorWith(vault);
    const st = await c.coordinator.restore();
    expect(st.state).toBe("temporarilyUnavailable");
    expect(vault.creds).not.toBeNull(); // never wiped on availability failures
    expect(vault.session).not.toBeNull();
  });

  it("invalid stored credentials → userActionRequired once, stale secrets purged", async () => {
    const vault = new MemoryVault();
    vault.creds = { username: "s0088", password: "pw-WRONG" };
    vault.session = null;

    const c = connectorWith(vault);
    const st = await c.coordinator.restore();
    expect(st.state).toBe("userActionRequired");
    expect(vault.creds).toBeNull(); // purged: no login-storm on a dead password
    expect(state.loginCount).toBe(1);
  });

  it("5xx during an authenticated read keeps the session (no sign-out)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getPermits(); // establishes a session
    const before = vault.session;
    expect(before).not.toBeNull();

    state.mode = "offline5xx";
    await expect(c.getPermits()).rejects.toSatisfy(
      (e: unknown) => isPortalError(e) && e.kind === "serverUnavailable",
    );
    expect(vault.session).toBe(before); // untouched
  });

  it("maintenance HTML page → serverUnavailable, not incompatible", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getPermits();
    state.mode = "maintenanceHtml";
    await expect(c.getPermits()).rejects.toSatisfy(
      (e: unknown) => isPortalError(e) && e.kind === "serverUnavailable",
    );
  });

  it("unknown HTML page → schemaIncompatible (circuit-break, keep cache upstream)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getPermits();
    state.mode = "unknownHtml";
    await expect(c.getPermits()).rejects.toSatisfy(
      (e: unknown) => isPortalError(e) && e.kind === "schemaIncompatible",
    );
  });

  it("login CAPTCHA/challenge page → userActionRequired", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    state.mode = "loginChallengeHtml";
    const c = connectorWith(vault);
    const st = await c.coordinator.restore();
    expect(st.state).toBe("userActionRequired");
  });

  it("door open: timeout → outcomeUnknown, NO automatic second POST", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault, 500); // short timeout
    await c.getDoors(); // establish session

    state.mode = "openDoorHang";
    const err = await c
      .openDoor({ permitRecordId: -2, doorKey: "door-front-01" })
      .then(() => null)
      .catch((e: unknown) => e);
    expect(isPortalError(err) && err.kind === "timeout").toBe(true);
    expect(isPortalError(err) && err.info.kind === "timeout" && err.info.outcomeUnknown).toBe(true);
    // Exactly one request reached the portal; absolutely no retry was issued.
    await new Promise((r) => setTimeout(r, 700));
    expect(state.doorRequestCount).toBe(1);
    expect(state.openDoorCalls.length).toBe(0); // and it never completed server-side
  });

  it("door open after session expiry → fresh session but NO auto-replay of the mutation", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getDoors();

    // Invalidate the live token server-side to force 401 on the next call.
    state.tokens.clear();
    const err = await c
      .openDoor({ permitRecordId: 501, doorKey: "door-back-02" })
      .then(() => null)
      .catch((e: unknown) => e);
    expect(isPortalError(err) && err.kind === "sessionExpired").toBe(true);
    expect(state.openDoorCalls.length).toBe(0); // mutation not silently replayed
    // ...but the session has been silently repaired for the user's retry:
    await c.openDoor({ permitRecordId: 501, doorKey: "door-back-02" });
    expect(state.openDoorCalls.length).toBe(1);
    expect(state.loginCount).toBe(2); // initial + one silent repair
  });

  it("door-open rejection (status 1) is operationRejected, NEVER success (C2)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getDoors();
    state.mode = "doorRejects";
    const err = await c
      .openDoor({ permitRecordId: -2, doorKey: "door-front-01" })
      .then(() => null)
      .catch((e: unknown) => e);
    expect(isPortalError(err) && err.kind === "operationRejected").toBe(true);
  });

  it("maintenance page during silent re-login → temporarilyUnavailable, NOT a password prompt (C3)", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    vault.session = null;
    state.mode = "loginMaintenanceHtml";
    const c = connectorWith(vault);
    const st = await c.coordinator.restore();
    expect(st.state).toBe("temporarilyUnavailable");
    expect(vault.creds).not.toBeNull();
  });

  it("commuter door open sends record_id -2 with door_id === indexcode", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.openDoor({ permitRecordId: -2, doorKey: "door-front-01" });
    expect(state.openDoorCalls).toEqual([
      { record_id: -2, door_id: "door-front-01", indexcode: "door-front-01" },
    ]);
  });

  it("signOut clears local state and calls logout; forget wipes credentials too", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    await c.getPermits();
    expect(vault.session).not.toBeNull();

    await c.logout();
    expect(vault.session).toBeNull();
    expect(vault.creds).not.toBeNull(); // sign-out keeps saved school login

    await c.coordinator.forgetEverything();
    expect(vault.creds).toBeNull();
  });
});

describe("data endpoints", () => {
  it("getLessons joins weekly + lesson table on lesson_id and sorts chronologically", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);

    const from = new Date(2026, 7, 31); // Mon
    const to = new Date(2026, 8, 13); // next-next Sun — spans 2 portal weeks
    const lessons = await c.getLessons(from, to);
    expect(lessons.length).toBeGreaterThanOrEqual(2);
    const l = lessons[0]!;
    expect(l.subjectName).toBe("Physics");
    expect(l.subjectId).toBe("7"); // joined from lesson table
    expect(l.topicId).toBe("70");
    expect(l.roomId).toBe("204");
    expect(l.teacherDisplayName).toBe("Ms Mock");
    const times = lessons.map((x) => x.startsAt.getTime());
    expect([...times].sort((a, b) => a - b)).toEqual(times);
  });

  it("out-of-range weeks (portal status:1) are treated as empty, not schemaIncompatible", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    // Mark the earliest weeks in the range as portal-unavailable.
    const from = new Date(2026, 7, 31);
    const to = new Date(2026, 8, 13);
    state.outOfRangeBelow = 2957; // both requested weeks (2956/2957 area) — force the earlier one out of range
    const lessons = await c.getLessons(from, to);
    // No throw; only the in-range week's lessons come back.
    expect(Array.isArray(lessons)).toBe(true);
  });

  it("door list quirk: doors parsed from `message` with status===1", async () => {
    const vault = new MemoryVault();
    vault.creds = { ...GOOD };
    const c = connectorWith(vault);
    const doors = await c.getDoors();
    expect(doors.map((d) => d.key)).toEqual(["door-front-01", "door-back-02"]);
  });
});
