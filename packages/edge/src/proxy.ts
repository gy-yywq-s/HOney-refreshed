// The same-origin edge (spec §16.2, §29.5): one small reverse proxy on the
// public port, standard library only. It routes
//
//   /api/*        → HOney Core         (cookies/authorization pass through)
//   /community/*  → HOney Community    (Cookie, Authorization, account-derived
//                                       and Core request ids are REMOVED)
//   /access/{bootstrap,operations/*,health}
//                 → Access Service     (only Access-Capability / Access-Commit
//                                       reach it; nothing else identifying)
//   everything    → HOney Core         (the built web app)
//
// It never retries a request, never buffers a streamed response, logs only a
// route class + status, and bounds body size and time. Cloudflare's tunnel
// points at this port; the three services listen on loopback only.

import { createServer, request as httpRequest, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { randomUUID } from "node:crypto";

export interface EdgeConfig {
  core: { host: string; port: number };
  community: { host: string; port: number };
  access: { host: string; port: number };
  /** Bytes; a mutation body beyond this is refused before any upstream connection. */
  maxBodyBytes: number;
  /** Upstream headers timeout (ms); streamed progress responses stay open past it once headers arrived. */
  headersTimeoutMs: number;
  log?: (line: { id: string; lane: string; status: number; ms: number }) => void;
}

const STRIP_FOR_COMMUNITY = new Set(["cookie", "authorization", "x-honey-account", "x-honey-user", "x-honey-session", "x-request-id", "x-correlation-id", "cf-connecting-ip", "x-forwarded-for", "x-real-ip", "cf-ray", "cf-ipcountry", "forwarded"]);
const KEEP_FOR_ACCESS = new Set(["access-capability", "access-commit", "content-type", "content-length", "accept", "accept-encoding", "user-agent", "host", "connection", "transfer-encoding"]);
const HOP_BY_HOP = new Set(["connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailer", "transfer-encoding", "upgrade"]);

export type Lane = "api" | "community" | "access" | "web";

// The Access Service owns only its three resource roots under /access/; the
// rest of /access/* (e.g. /access/permits/new) is a screen of the web app and
// must deep-link like any other.
const ACCESS_ROOTS = ["/access/bootstrap", "/access/operations/", "/access/health"];

export function laneFor(url: string): Lane {
  if (url.startsWith("/community/")) return "community";
  if (ACCESS_ROOTS.some((root) => url === root || url.startsWith(root) || url.startsWith(root + "?"))) return "access";
  if (url.startsWith("/api/")) return "api";
  return "web";
}

/** The headers an upstream may see for a lane (identity material never crosses into Community/Access). */
export function upstreamHeaders(lane: Lane, incoming: IncomingMessage["headers"]): Record<string, string | string[]> {
  const out: Record<string, string | string[]> = {};
  for (const [name, value] of Object.entries(incoming)) {
    if (value === undefined || HOP_BY_HOP.has(name)) continue;
    if (lane === "community" && STRIP_FOR_COMMUNITY.has(name)) continue;
    if (lane === "access" && !KEEP_FOR_ACCESS.has(name)) continue;
    out[name] = value;
  }
  // Internal admin routes are never reachable from outside.
  return out;
}

export function isBlockedPath(url: string): boolean {
  return url.startsWith("/internal/") || url.includes("/internal/");
}

export function createEdge(config: EdgeConfig): Server {
  return createServer((req, res) => {
    const started = Date.now();
    const id = randomUUID();
    const url = req.url ?? "/";
    const lane = laneFor(url);
    const finish = (status: number) => config.log?.({ id, lane, status, ms: Date.now() - started });

    if (isBlockedPath(url)) {
      res.writeHead(404, { "content-type": "application/json" }).end('{"error":"not_found"}');
      finish(404);
      return;
    }
    const target = lane === "community" ? config.community : lane === "access" ? config.access : config.core;
    const method = req.method ?? "GET";
    const declared = Number(req.headers["content-length"] ?? 0);
    if (declared > config.maxBodyBytes) {
      res.writeHead(413, { "content-type": "application/json" }).end('{"error":"body_too_large"}');
      finish(413);
      return;
    }

    const upstream = httpRequest(
      { host: target.host, port: target.port, method, path: url, headers: upstreamHeaders(lane, req.headers), timeout: config.headersTimeoutMs },
      (up) => {
        const headers: Record<string, string | string[] | undefined> = {};
        for (const [name, value] of Object.entries(up.headers)) if (!HOP_BY_HOP.has(name)) headers[name] = value;
        // Streamed progress must reach the browser as it is produced.
        headers["x-accel-buffering"] = "no";
        res.writeHead(up.statusCode ?? 502, headers);
        up.pipe(res); // no buffering, no retry
        up.on("end", () => finish(up.statusCode ?? 502));
      },
    );
    upstream.on("timeout", () => {
      // Headers never arrived: the request is NOT retried — the caller learns
      // the outcome is unknown (a mutation may or may not have reached the service).
      upstream.destroy(new Error("upstream headers timeout"));
    });
    upstream.on("error", () => {
      if (!res.headersSent) {
        res.writeHead(502, { "content-type": "application/json" }).end('{"error":"upstream_unavailable"}');
        finish(502);
      } else {
        res.destroy();
      }
    });
    let received = 0;
    req.on("data", (chunk: Buffer) => {
      received += chunk.length;
      if (received > config.maxBodyBytes) {
        req.destroy();
        upstream.destroy();
        if (!res.headersSent) res.writeHead(413, { "content-type": "application/json" }).end('{"error":"body_too_large"}');
        finish(413);
      }
    });
    req.pipe(upstream);
    // A client that disappears mid-stream must not leave the upstream hanging.
    res.on("close", () => {
      if (!res.writableFinished) upstream.destroy();
    });
  });
}
