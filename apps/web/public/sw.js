// HOney service worker — deliberately small.
//
// Purpose: (1) PWA installability on Android; (2) instant repeat loads.
// Strategy: hashed build assets and fonts are cache-first (immutable by
// construction — vite content-hashes them); navigations and everything
// else are network-first with cache fallback, so a deploy is picked up on
// the next load and the app still opens offline with its last shell.
// /api/ requests are NEVER cached — data freshness is the app's job
// (it has its own in-memory SWR layer).
const CACHE = "honey-v3"; // plus: activate evicts hashed assets the live index no longer references

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.add("/").catch(() => {}))
      .then(() => self.skipWaiting()),
  );
});

async function liveAssetSet(html) {
  // Index refs, then every css url() and js import (Vite emits relative
  // "./Chunk-hash.js") those files carry — fonts and lazy chunks are live.
  const abs = (p, base) => new URL(p, base || self.location.origin).href;
  const seed = (html.match(/\/assets\/[^"' )]+/g) ?? []).map((p) => abs(p));
  const live = new Set(seed);
  const cache = await caches.open(CACHE);
  const queue = [...seed];
  while (queue.length) {
    const href = queue.shift();
    if (!/\.(js|css)$/.test(href)) continue;
    try {
      const hit = await cache.match(href);
      const txt = await (hit ?? (await fetch(href))).text();
      const refs = txt.match(/(?:\.\.?\/)?[A-Za-z0-9_./-]*assets\/[A-Za-z0-9_.-]+\.(?:js|css|woff2)|\.\/[A-Za-z0-9_-]+-[A-Za-z0-9_-]+\.js/g) ?? [];
      for (const r of refs) {
        const u = abs(r, href);
        if (!live.has(u)) { live.add(u); queue.push(u); }
      }
    } catch { /* keep what we have */ }
  }
  return live;
}
async function evictStaleAssets(html) {
  try {
    if (!html) {
      const res = await fetch("/", { cache: "no-store" });
      if (!res.ok) return;
      html = await res.text();
    }
    const live = await liveAssetSet(html);
    const cache = await caches.open(CACHE);
    for (const req of await cache.keys()) {
      const u = new URL(req.url);
      if (u.pathname.startsWith("/assets/") && !live.has(req.url)) await cache.delete(req);
    }
    await cache.put(SIG_KEY, new Response(indexSignature(html)));
  } catch {
    /* offline at activate — nothing to evict against */
  }
}
const SIG_KEY = "/__index-sig";
function indexSignature(html) {
  return (html.match(/\/assets\/[^"' )]+/g) ?? []).sort().join("|");
}

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
        .then(() => evictStaleAssets())
        .then(() => self.clients.claim()),
    ),
  );
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== "GET" || url.origin !== self.location.origin) return;
  if (url.pathname.startsWith("/api/")) return;

  const immutable = url.pathname.startsWith("/assets/") || url.pathname.endsWith(".woff2");
  if (immutable) {
    event.respondWith(
      caches.open(CACHE).then((cache) =>
        cache.match(event.request).then(
          (hit) =>
            hit ??
            fetch(event.request).then((res) => {
              // Only real assets: the origin answers a missing hash with a
              // 200 HTML shell, which must never be cached under /assets/.
              const type = res.headers.get("content-type") ?? "";
              if (res.ok && /javascript|css|font|octet-stream/.test(type)) cache.put(event.request, res.clone());
              return res;
            }),
        ),
      ),
    );
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((res) => {
        if (res.ok && event.request.mode === "navigate") {
          // One shell only ('/'): every route serves the same document, so
          // caching each path just accumulates copies.
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put("/", copy));
          // A deploy that changed only hashes: evict when the index changes.
          res.clone().text().then(async (html) => {
            const sig = indexSignature(html);
            if (!sig) return;
            const cache = await caches.open(CACHE);
            const stored = await cache.match(SIG_KEY).then((r) => (r ? r.text() : ""));
            if (stored !== sig) await evictStaleAssets(html);
          }).catch(() => {});
        }
        return res;
      })
      .catch(() =>
        caches.open(CACHE).then((cache) =>
          cache.match(event.request).then((hit) => hit ?? (event.request.mode === "navigate" ? cache.match("/") : undefined)),
        ),
      ),
  );
});
