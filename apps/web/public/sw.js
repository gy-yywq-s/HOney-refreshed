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

async function evictStaleAssets() {
  // Self-evicting: a deploy that changes only hashes still drops the old
  // /assets/* entries — whatever the fresh index does not reference goes.
  try {
    const res = await fetch("/", { cache: "no-store" });
    if (!res.ok) return;
    const html = await res.text();
    const live = new Set((html.match(/\/assets\/[^"' )]+/g) ?? []).map((p) => new URL(p, self.location.origin).href));
    const cache = await caches.open(CACHE);
    for (const req of await cache.keys()) {
      const u = new URL(req.url);
      if (u.pathname.startsWith("/assets/") && !live.has(req.url)) await cache.delete(req);
    }
  } catch {
    /* offline at activate — nothing to evict against */
  }
}

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
        .then(evictStaleAssets)
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
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(event.request, copy));
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
