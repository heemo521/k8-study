// K8 Study offline service worker (spec §8).
//
// The two placeholders below are filled in by `dart run tool/gen_precache.dart`
// after `flutter build web`. An unprocessed copy (e.g. `flutter run`) does
// nothing, so it can never serve stale development assets.
const BUILD = '__BUILD_HASH__';
const PRECACHE = /*__PRECACHE_LIST__*/[];

const PREFIX = 'k8study-';
const CACHE = PREFIX + BUILD;
const ACTIVE = BUILD !== '__BUILD' + '_HASH__';

self.addEventListener('install', (event) => {
  if (!ACTIVE) return;
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(PRECACHE.map((p) => new Request(p, { cache: 'reload' }))))
      // First install: take over right away (no older app is running).
      // Updates wait until the old version's tabs close, so one page never
      // mixes files from two builds.
      .then(() => { if (!self.registration.active) return self.skipWaiting(); })
  );
});

self.addEventListener('activate', (event) => {
  if (!ACTIVE) return;
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k.startsWith(PREFIX) && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function isAppShell(request, url) {
  const scope = new URL(self.registration.scope);
  return request.mode === 'navigate' ||
    url.href === scope.href ||
    url.href === new URL('index.html', scope).href;
}

self.addEventListener('fetch', (event) => {
  if (!ACTIVE) return;
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (isAppShell(request, url)) {
    // Network-first for index.html so a new build is picked up when online.
    const shell = new URL('index.html', self.registration.scope).href;
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE).then((c) => c.put(shell, copy));
          }
          return response;
        })
        .catch(() => caches.match(shell))
    );
    return;
  }

  // Cache-first for everything else; cache what is fetched on first use.
  event.respondWith(
    caches.match(request).then((cached) => cached || fetch(request).then((response) => {
      if (response.ok && response.type === 'basic') {
        const copy = response.clone();
        caches.open(CACHE).then((c) => c.put(request, copy));
      }
      return response;
    }))
  );
});
