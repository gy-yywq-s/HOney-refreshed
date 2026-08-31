import { describe, expect, it, vi } from "vitest";
import { ApiClient, ApiError } from "./client";
import type { FetchLike, SessionStorageLike } from "./client";
import type { Me, SessionTokens } from "./types";

const SESSION_KEY = "HOney.session";

const session: SessionTokens = {
  accessToken: "at-1",
  accessExpiresAt: "2026-08-31T13:00:00Z",
  refreshToken: "rt-1",
  refreshExpiresAt: "2026-09-30T12:00:00Z",
};

const refreshedSession: SessionTokens = {
  accessToken: "at-2",
  accessExpiresAt: "2026-08-31T14:00:00Z",
  refreshToken: "rt-2",
  refreshExpiresAt: "2026-09-30T13:00:00Z",
};

const meBody: Me = {
  honeyId: "hx7k2p",
  displayName: "Gary",
  isAdmin: false,
  consent: { timetable: true, grantedAt: "2026-08-31T10:00:00Z" },
  connection: { connected: true, lastSyncedAt: "2026-08-31T11:00:00Z", portalTokenValid: true },
};

function memoryStorage(): SessionStorageLike {
  const map = new Map<string, string>();
  return {
    getItem: (key) => map.get(key) ?? null,
    setItem: (key, value) => void map.set(key, value),
    removeItem: (key) => void map.delete(key),
  };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function authOf(init?: RequestInit): string | undefined {
  return (init?.headers as Record<string, string> | undefined)?.["Authorization"];
}

describe("ApiClient login", () => {
  const loginBody = {
    honeyId: "hx7k2p",
    displayName: "Gary",
    created: true,
    isAdmin: false,
    consent: { timetable: true },
    session,
  };

  it("posts credentials without auth and stores the returned session", async () => {
    const storage = memoryStorage();
    const fetchFn = vi.fn<FetchLike>().mockResolvedValueOnce(json(200, loginBody));
    const client = new ApiClient({ fetchFn, storage });

    const result = await client.login({ username: "s1234", password: "pw", consentTimetable: true });

    expect(result.honeyId).toBe("hx7k2p");
    expect(client.hasSession()).toBe(true);
    expect(JSON.parse(storage.getItem(SESSION_KEY) ?? "")).toEqual(session);

    const [url, init] = fetchFn.mock.calls[0]!;
    expect(url).toBe("/api/auth/login");
    expect(init?.method).toBe("POST");
    expect(authOf(init)).toBeUndefined();
    expect(JSON.parse(String(init?.body))).toEqual({
      username: "s1234",
      password: "pw",
      consentTimetable: true,
    });
  });

  it("surfaces school_credentials_rejected as a typed error without storing a session", async () => {
    const storage = memoryStorage();
    const fetchFn = vi
      .fn<FetchLike>()
      .mockResolvedValueOnce(json(401, { error: "school_credentials_rejected" }));
    const client = new ApiClient({ fetchFn, storage });

    await expect(client.login({ username: "s1234", password: "nope" })).rejects.toMatchObject({
      name: "ApiError",
      status: 401,
      code: "school_credentials_rejected",
    });
    expect(client.hasSession()).toBe(false);
  });

  it("maps a bodyless 503 to portal_unavailable", async () => {
    const fetchFn = vi.fn<FetchLike>().mockResolvedValueOnce(new Response(null, { status: 503 }));
    const client = new ApiClient({ fetchFn, storage: memoryStorage() });

    await expect(client.login({ username: "s1234", password: "pw" })).rejects.toMatchObject({
      status: 503,
      code: "portal_unavailable",
    });
  });
});

describe("ApiClient refresh-on-401", () => {
  it("refreshes once, retries with the new token, and persists the new session", async () => {
    const storage = memoryStorage();
    storage.setItem(SESSION_KEY, JSON.stringify(session));

    const refreshCalls: unknown[] = [];
    const fetchFn: FetchLike = async (url, init) => {
      if (url === "/api/auth/refresh") {
        refreshCalls.push(JSON.parse(String(init?.body)));
        return json(200, refreshedSession);
      }
      if (url === "/api/me") {
        return authOf(init) === `Bearer ${refreshedSession.accessToken}`
          ? json(200, meBody)
          : json(401, { error: "token_expired" });
      }
      return json(500, { error: "unexpected_route" });
    };
    const client = new ApiClient({ fetchFn, storage });

    const me = await client.me();

    expect(me.honeyId).toBe("hx7k2p");
    expect(refreshCalls).toEqual([{ refreshToken: "rt-1" }]);
    expect(JSON.parse(storage.getItem(SESSION_KEY) ?? "")).toEqual(refreshedSession);
  });

  it("deduplicates concurrent refreshes (single-flight)", async () => {
    const storage = memoryStorage();
    storage.setItem(SESSION_KEY, JSON.stringify(session));

    let refreshCount = 0;
    const fetchFn: FetchLike = async (url, init) => {
      if (url === "/api/auth/refresh") {
        refreshCount += 1;
        return json(200, refreshedSession);
      }
      return authOf(init) === `Bearer ${refreshedSession.accessToken}`
        ? json(200, meBody)
        : json(401, { error: "token_expired" });
    };
    const client = new ApiClient({ fetchFn, storage });

    await Promise.all([client.me(), client.me()]);

    expect(refreshCount).toBe(1);
  });

  it("clears the session and signals loss when the refresh is rejected", async () => {
    const storage = memoryStorage();
    storage.setItem(SESSION_KEY, JSON.stringify(session));

    const fetchFn: FetchLike = async (url) =>
      url === "/api/auth/refresh"
        ? json(401, { error: "invalid_refresh_token" })
        : json(401, { error: "token_expired" });
    const client = new ApiClient({ fetchFn, storage });
    const onSessionLost = vi.fn();
    client.onSessionLost = onSessionLost;

    await expect(client.me()).rejects.toMatchObject({ status: 401, code: "session_expired" });
    expect(client.hasSession()).toBe(false);
    expect(onSessionLost).toHaveBeenCalledTimes(1);
  });

  it("throws a typed error when there is no session at all", async () => {
    const fetchFn = vi.fn<FetchLike>();
    const client = new ApiClient({ fetchFn, storage: memoryStorage() });

    await expect(client.me()).rejects.toBeInstanceOf(ApiError);
    expect(fetchFn).not.toHaveBeenCalled();
  });
});
