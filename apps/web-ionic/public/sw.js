// HOney service worker — deliberately small.
//
// Purpose: (1) PWA installability on Android; (2) instant repeat loads.
// Strategy: hashed build assets and fonts are cache-first (immutable by
// construction — vite content-hashes them); navigations and everything
// else are network-first with cache fallback, so a deploy is picked up on
// the next load and the app still opens offline with its last shell.
// /api/ requests are NEVER cached — data freshness is the app's job
// (it has its own in-memory SWR layer).
const CACHE = "honey-ionic-v1";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.add("/").catch(() => {}))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))).then(() => self.clients.claim()),
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
              if (res.ok) cache.put(event.request, res.clone());
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
