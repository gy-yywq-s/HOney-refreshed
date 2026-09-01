import { createReadStream, existsSync, statSync } from "node:fs";
import { createServer, request as proxyRequest } from "node:http";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./dist/", import.meta.url));
const port = Number(process.env.PORT ?? 4174);
const mime = { ".css": "text/css; charset=utf-8", ".html": "text/html; charset=utf-8", ".ico": "image/x-icon", ".js": "text/javascript; charset=utf-8", ".json": "application/json; charset=utf-8", ".png": "image/png", ".svg": "image/svg+xml", ".webmanifest": "application/manifest+json" };

const server = createServer((incoming, outgoing) => {
  const url = new URL(incoming.url ?? "/", "http://127.0.0.1");
  if (url.pathname === "/healthz") return send(outgoing, 200, "text/plain; charset=utf-8", "ok\n");
  if (url.pathname === "/api" || url.pathname.startsWith("/api/")) return proxyApi(incoming, outgoing);

  const safe = normalize(decodeURIComponent(url.pathname))
    .replace(/^(\.\.(\/|\\|$))+/, "")
    .replace(/^[/\\]+/, "");
  let file = join(root, safe === "/" ? "index.html" : safe);
  if (!file.startsWith(root) || !existsSync(file) || statSync(file).isDirectory()) file = join(root, "index.html");
  const type = mime[extname(file)] ?? "application/octet-stream";
  outgoing.writeHead(200, {
    "Content-Type": type,
    "Cache-Control": file.endsWith("index.html") || file.endsWith("sw.js") ? "no-cache" : "public, max-age=31536000, immutable",
    "Content-Security-Policy": "default-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; font-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self' https://www.huayaopudong.com",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
  });
  createReadStream(file).pipe(outgoing);
});

function proxyApi(incoming, outgoing) {
  const headers = { ...incoming.headers, host: "127.0.0.1:8871", "x-forwarded-host": incoming.headers.host ?? "honey.gaelis.cc", "x-forwarded-proto": "https" };
  const proxied = proxyRequest({ hostname: "127.0.0.1", port: 8871, path: incoming.url, method: incoming.method, headers }, (response) => {
    outgoing.writeHead(response.statusCode ?? 502, response.headers);
    response.pipe(outgoing);
  });
  proxied.on("error", () => send(outgoing, 502, "application/json", JSON.stringify({ error: "backend_unavailable" })));
  incoming.pipe(proxied);
}

function send(response, status, type, body) {
  response.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store" });
  response.end(body);
}

server.listen(port, "127.0.0.1", () => process.stdout.write(`HOney Ionic Web listening on 127.0.0.1:${port}\n`));
