import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer, request as proxyRequest } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./dist/", import.meta.url));
const port = Number(process.env.PORT ?? 4174);
const publicOrigin = process.env.PUBLIC_ORIGIN ?? "https://honey.gaelis.cc";
const hsts = "max-age=31536000";
const mime = { ".css": "text/css; charset=utf-8", ".html": "text/html; charset=utf-8", ".ico": "image/x-icon", ".js": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8", ".png": "image/png", ".svg": "image/svg+xml", ".webmanifest": "application/manifest+json" };

const server = createServer((incoming, outgoing) => {
  const url = new URL(incoming.url ?? "/", "http://127.0.0.1");
  if (isForwardedHttp(incoming)) {
    const destination = new URL(`${url.pathname}${url.search}`, publicOrigin);
    outgoing.writeHead(308, { Location: destination.href, "Cache-Control": "no-store" });
    return outgoing.end();
  }
  if (url.pathname === "/healthz") return send(outgoing, 200, "text/plain; charset=utf-8", "ok\n");
  if (url.pathname === "/api" || url.pathname.startsWith("/api/")) return proxyApi(incoming, outgoing);

  const safe = normalize(decodeURIComponent(url.pathname))
    .replace(/^(\.\.(\/|\\|$))+/, "")
    .replace(/^[/\\]+/, "");
  let file = join(root, safe === "/" ? "index.html" : safe);
  if (!file.startsWith(root) || !existsSync(file) || statSync(file).isDirectory()) file = join(root, "index.html");
  const type = mime[extname(file)] ?? "application/octet-stream";
  const isServiceWorker = file.endsWith("sw.js");
  outgoing.writeHead(200, {
    "Content-Type": type,
    "Cache-Control": isServiceWorker ? "no-store, no-cache, must-revalidate" : file.endsWith("index.html") ? "no-cache, no-transform" : "public, max-age=31536000, immutable",
    ...(isServiceWorker ? { "CDN-Cache-Control": "no-store", "Cloudflare-CDN-Cache-Control": "no-store", Expires: "0", "Service-Worker-Allowed": "/" } : {}),
    "Content-Security-Policy": "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self' https://www.huayaopudong.com",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Strict-Transport-Security": hsts,
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });
  createReadStream(file).pipe(outgoing);
});

function proxyApi(incoming, outgoing) {
  const headers = { ...incoming.headers, host: "127.0.0.1:8871", "x-forwarded-host": incoming.headers.host ?? "honey.gaelis.cc", "x-forwarded-proto": "https" };
  let timedOut = false;
  const proxied = proxyRequest({ hostname: "127.0.0.1", port: 8871, path: incoming.url, method: incoming.method, headers }, (response) => {
    outgoing.writeHead(response.statusCode ?? 502, { ...response.headers, "strict-transport-security": hsts });
    response.pipe(outgoing);
  });
  proxied.setTimeout(65_000, () => { timedOut = true; proxied.destroy(); });
  proxied.on("error", () => {
    if (outgoing.headersSent) return outgoing.destroy();
    send(outgoing, timedOut ? 504 : 502, "application/json", JSON.stringify({ error: timedOut ? "backend_timeout" : "backend_unavailable" }));
  });
  incoming.on("aborted", () => proxied.destroy());
  incoming.pipe(proxied);
}

function send(response, status, type, body) {
  response.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store", "Strict-Transport-Security": hsts });
  response.end(body);
}

function isForwardedHttp(request) {
  const forwarded = String(request.headers["x-forwarded-proto"] ?? "").split(",", 1)[0].trim().toLowerCase();
  if (forwarded === "http") return true;
  const visitor = String(request.headers["cf-visitor"] ?? "");
  return /"scheme"\s*:\s*"http"/i.test(visitor);
}

server.listen(port, "127.0.0.1", () => process.stdout.write(`HOney Ionic Web listening on 127.0.0.1:${port}\n`));
