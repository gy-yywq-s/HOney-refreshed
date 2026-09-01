// @vitest-environment jsdom
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { FeedPage, LoginResponse } from "@honey/shared/api";
import { LiveClient, type FetchLike } from "./client";

const login: LoginResponse = {
  honeyId: "fixture-id",
  displayName: "Fixture Student",
  created: false,
  isAdmin: false,
  consent: { timetable: true },
  session: {
    accessToken: "access-test",
    accessExpiresAt: "2099-01-01T00:00:00Z",
    refreshToken: "refresh-test",
    refreshExpiresAt: "2099-02-01T00:00:00Z",
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

describe("Ionic live API adapter", () => {
  beforeEach(() => localStorage.clear());

  it("decodes shared login/feed shapes and emits the canonical feed query", async () => {
    const feed: FeedPage = { items: [], nextCursor: "opaque-next", headCursor: "opaque-head" };
    const fetchFn = vi.fn<FetchLike>()
      .mockResolvedValueOnce(json(login))
      .mockResolvedValueOnce(json(feed));
    const client = new LiveClient(fetchFn);

    await client.login({ username: "student", password: "test-only" });
    const result = await client.feedPage({ scope: "school", cursor: "opaque cursor", limit: 12 });

    expect(result).toEqual(feed);
    expect(fetchFn.mock.calls[1]?.[0]).toBe("/api/experiences/feed?scope=school&cursor=opaque+cursor&limit=12");
    expect((fetchFn.mock.calls[1]?.[1]?.headers as Record<string, string>).Authorization).toBe("Bearer access-test");
  });

  it("fails closed on a network error", async () => {
    const client = new LiveClient(vi.fn<FetchLike>().mockRejectedValue(new Error("offline")));
    await expect(client.login({ username: "student", password: "test-only" })).rejects.toMatchObject({
      status: 0,
      code: "network_error",
    });
  });

  it("bounds a stalled sign-in and reports a specific timeout", async () => {
    const fetchFn: FetchLike = (_input, init) => new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => reject(new DOMException("Aborted", "AbortError")));
    });
    const client = new LiveClient(fetchFn, 5, 5);

    await expect(client.login({ username: "student", password: "test-only" })).rejects.toMatchObject({
      status: 0,
      code: "request_timeout",
    });
  });
});
