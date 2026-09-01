import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer, request as proxyRequest } from "node:http";
import { extname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./dist/", import.meta.url)).replace(/[\\/]$/, "");
const port = Number(process.env.PORT ?? 4174);
const publicOrigin = new URL(process.env.PUBLIC_ORIGIN ?? "https://ionic.gaelisus.com");
const backendPort = Number(process.env.HONEY_BACKEND_PORT ?? 8871);
const hsts = "max-age=31536000";
const mime = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
};

const server = createServer((incoming, outgoing) => {
  let url;
  try {
    url = new URL(incoming.url ?? "/", "http://127.0.0.1");
  } catch {
    return send(outgoing, 400, "text/plain; charset=utf-8", "Bad request\n");
  }

  if (isForwardedHttp(incoming)) {
    const destination = new URL(`${url.pathname}${url.search}`, publicOrigin);
    outgoing.writeHead(308, { Location: destination.href, "Cache-Control": "no-store" });
    return outgoing.end();
  }

  if (url.pathname === "/healthz") return send(outgoing, 200, "text/plain; charset=utf-8", "ok\n");
  if (url.pathname === "/api" || url.pathname.startsWith("/api/")) return proxyApi(incoming, outgoing);
  if (incoming.method !== "GET" && incoming.method !== "HEAD") {
    return send(outgoing, 405, "text/plain; charset=utf-8", "Method not allowed\n");
  }

  let pathname;
  try {
    pathname = decodeURIComponent(url.pathname);
  } catch {
    return send(outgoing, 400, "text/plain; charset=utf-8", "Bad request\n");
  }

  const requested = resolve(root, `.${pathname}`);
  const insideRoot = requested === root || requested.startsWith(`${root}${sep}`);
  let file = insideRoot ? requested : resolve(root, "index.html");
  if (!existsSync(file) || statSync(file).isDirectory()) file = resolve(root, "index.html");

  const isIndex = file.endsWith(`${sep}index.html`);
  const isServiceWorker = file.endsWith(`${sep}sw.js`);
  const isManifest = file.endsWith(`${sep}manifest.webmanifest`);
  const immutableAsset = file.includes(`${sep}assets${sep}`);
  const cacheControl =
    isServiceWorker || isManifest
      ? "no-store, no-cache, must-revalidate"
      : isIndex
        ? "no-cache, no-transform"
        : immutableAsset
          ? "public, max-age=31536000, immutable"
          : "public, max-age=86400";

  outgoing.writeHead(200, {
    "Content-Type": mime[extname(file)] ?? "application/octet-stream",
    "Cache-Control": cacheControl,
    ...(isServiceWorker
      ? {
          "CDN-Cache-Control": "no-store",
          "Cloudflare-CDN-Cache-Control": "no-store",
          Expires: "0",
          "Service-Worker-Allowed": "/",
        }
      : {}),
    "Content-Security-Policy":
      "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'sha256-6bYUnOliyCFHkBw5FmodTCLinKMBIYMDghq4m5i9kAc='; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self' https://www.huayaopudong.com",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Strict-Transport-Security": hsts,
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });

  if (incoming.method === "HEAD") return outgoing.end();
  createReadStream(file).pipe(outgoing);
});

function proxyApi(incoming, outgoing) {
  let timedOut = false;
  const headers = {
    ...incoming.headers,
    host: `127.0.0.1:${backendPort}`,
    "x-forwarded-host": publicOrigin.host,
    "x-forwarded-proto": "https",
  };
  const proxied = proxyRequest(
    {
      hostname: "127.0.0.1",
      port: backendPort,
      path: incoming.url,
      method: incoming.method,
      headers,
    },
    (response) => {
      outgoing.writeHead(response.statusCode ?? 502, {
        ...response.headers,
        "strict-transport-security": hsts,
      });
      response.pipe(outgoing);
    },
  );
  proxied.setTimeout(65_000, () => {
    timedOut = true;
    proxied.destroy();
  });
  proxied.on("error", () => {
    if (outgoing.headersSent) return outgoing.destroy();
    send(
      outgoing,
      timedOut ? 504 : 502,
      "application/json",
      JSON.stringify({ error: timedOut ? "backend_timeout" : "backend_unavailable" }),
    );
  });
  incoming.on("aborted", () => proxied.destroy());
  incoming.pipe(proxied);
}

function send(response, status, type, body) {
  response.writeHead(status, {
    "Content-Type": type,
    "Cache-Control": "no-store",
    "Strict-Transport-Security": hsts,
  });
  response.end(body);
}

function isForwardedHttp(request) {
  const forwarded = String(request.headers["x-forwarded-proto"] ?? "")
    .split(",", 1)[0]
    .trim()
    .toLowerCase();
  if (forwarded === "http") return true;
  return /"scheme"\s*:\s*"http"/i.test(String(request.headers["cf-visitor"] ?? ""));
}

server.listen(port, "127.0.0.1", () => {
  process.stdout.write(`HOney Ionic Web listening on 127.0.0.1:${port}\n`);
});
