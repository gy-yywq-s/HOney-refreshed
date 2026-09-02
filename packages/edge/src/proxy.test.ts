import { createServer, type IncomingMessage, type Server } from "node:http";
import type { AddressInfo } from "node:net";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { createEdge, laneFor, upstreamHeaders } from "./proxy.js";

// The edge's guarantees (spec §16.2, §29.5, §42.2 no.11–12): identity material
// never reaches Community or Access, internal routes are unreachable from
// outside, mutations are never retried, streams are not buffered, oversized
// bodies are refused before any upstream connection.

interface Seen {
  lane: string;
  headers: IncomingMessage["headers"];
  url: string;
  method: string;
  body: string;
}

function upstream(lane: string, seen: Seen[], behave?: (req: IncomingMessage, res: import("node:http").ServerResponse) => boolean): Promise<Server> {
  return new Promise((resolve) => {
    const s = createServer((req, res) => {
      let body = "";
      req.on("data", (c: Buffer) => (body += c.toString()));
      req.on("end", () => {
        seen.push({ lane, headers: req.headers, url: req.url ?? "", method: req.method ?? "", body });
        if (behave?.(req, res)) return;
        res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify({ lane }));
      });
    });
    s.listen(0, "127.0.0.1", () => resolve(s));
  });
}

let core: Server;
let community: Server;
let access: Server;
let edge: Server;
let seen: Seen[];
let base: string;
const port = (s: Server) => (s.address() as AddressInfo).port;

beforeEach(async () => {
  seen = [];
  core = await upstream("core", seen);
  community = await upstream("community", seen);
  access = await upstream("access", seen, (req, res) => {
    if (req.url === "/access/v1/stream") {
      res.writeHead(200, { "content-type": "application/x-ndjson" });
      res.write('{"stage":"accepted"}\n');
      setTimeout(() => res.end('{"stage":"confirmed","terminal":true}\n'), 150);
      return true;
    }
    if (req.url === "/access/v1/hang") return true; // never answers
    return false;
  });
  edge = createEdge({
    core: { host: "127.0.0.1", port: port(core) },
    community: { host: "127.0.0.1", port: port(community) },
    access: { host: "127.0.0.1", port: port(access) },
    maxBodyBytes: 1024,
    headersTimeoutMs: 300,
  });
  await new Promise<void>((r) => edge.listen(0, "127.0.0.1", () => r()));
  base = `http://127.0.0.1:${port(edge)}`;
});

afterEach(async () => {
  for (const s of [edge, core, community, access]) await new Promise<void>((r) => s.close(() => r()));
});

describe("lanes", () => {
  it("routes by prefix and strips identity material for Community and Access only", async () => {
    const headers = { cookie: "HOney=1", authorization: "Bearer abc", "x-request-id": "core-123", "x-honey-account": "u1", "access-capability": "cap", "access-commit": "commit" };
    const laneOf = async (r: Response) => ((await r.json()) as { lane: string }).lane;
    expect(await laneOf(await fetch(`${base}/api/me`, { headers }))).toBe("core");
    expect(await laneOf(await fetch(`${base}/community/v2/feed`, { method: "POST", headers, body: "{}" }))).toBe("community");
    expect(await laneOf(await fetch(`${base}/access/v1/bootstrap`, { headers }))).toBe("access");
    expect(await laneOf(await fetch(`${base}/settings`, { headers }))).toBe("core");
    const toCore = seen.find((s) => s.url === "/api/me")!;
    expect(toCore.headers.cookie).toBe("HOney=1");
    expect(toCore.headers.authorization).toBe("Bearer abc");
    const toCommunity = seen.find((s) => s.lane === "community")!;
    for (const h of ["cookie", "authorization", "x-request-id", "x-honey-account", "x-forwarded-for"]) expect(toCommunity.headers[h]).toBeUndefined();
    const toAccess = seen.find((s) => s.lane === "access")!;
    expect(toAccess.headers["access-capability"]).toBe("cap");
    expect(toAccess.headers["access-commit"]).toBe("commit");
    expect(toAccess.headers.cookie).toBeUndefined();
    expect(toAccess.headers.authorization).toBeUndefined();
  });

  it("internal routes are unreachable from outside", async () => {
    expect((await fetch(`${base}/internal/admin/status`)).status).toBe(404);
    expect((await fetch(`${base}/community/internal/admin/status`)).status).toBe(404);
    expect(seen).toHaveLength(0);
  });

  it("refuses an oversized body before contacting any upstream", async () => {
    const res = await fetch(`${base}/access/v1/operations/prepare`, { method: "POST", headers: { "content-length": "5000", "content-type": "application/json" }, body: "x".repeat(5000) });
    expect(res.status).toBe(413);
    expect(seen).toHaveLength(0);
  });
});

describe("mutations and streams", () => {
  it("never retries: a headers timeout surfaces as one 502 and exactly one upstream request", async () => {
    const res = await fetch(`${base}/access/v1/hang`, { method: "POST", body: "{}" });
    expect(res.status).toBe(502);
    await new Promise((r) => setTimeout(r, 400));
    expect(seen.filter((s) => s.url === "/access/v1/hang")).toHaveLength(1);
  });

  it("streams NDJSON progress chunks as they arrive (no buffering)", async () => {
    const res = await fetch(`${base}/access/v1/stream`);
    const reader = res.body!.getReader();
    const t0 = Date.now();
    const first = await reader.read();
    const firstAt = Date.now() - t0;
    expect(new TextDecoder().decode(first.value)).toContain("accepted");
    const rest = await reader.read();
    expect(new TextDecoder().decode(rest.value)).toContain("confirmed");
    expect(firstAt).toBeLessThan(120); // the first chunk did not wait for the second
  });
});

describe("pure helpers", () => {
  it("laneFor and upstreamHeaders", () => {
    expect(laneFor("/community/v2/check")).toBe("community");
    expect(laneFor("/access/v1/x")).toBe("access");
    expect(laneFor("/api/x")).toBe("api");
    expect(laneFor("/")).toBe("web");
    expect(upstreamHeaders("community", { cookie: "a", accept: "b", "x-forwarded-for": "1.2.3.4" })).toEqual({ accept: "b" });
    expect(upstreamHeaders("access", { cookie: "a", "access-capability": "c", "x-custom": "d" })).toEqual({ "access-capability": "c" });
  });
});
