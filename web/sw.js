// GymMane offline service worker. The build fills in VERSION, CORE and ALL
// (see tool/web/make_sw.py). Everything is served cache-first so the app
// works with no signal at the gym; a new deploy ships a new VERSION.
const VERSION = '__VERSION__';
const CORE = __CORE__;
const ALL = __ALL__;
const CACHE = 'gymmane-' + VERSION;

const url = (p) => new URL(p, self.registration.scope).toString();

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((c) => c.addAll(CORE.map((p) => new Request(url(p), { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('gymmane-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

async function warm() {
  const cache = await caches.open(CACHE);
  for (const p of ALL) {
    const u = url(p);
    if (await cache.match(u)) continue;
    try {
      const res = await fetch(u, { cache: 'reload' });
      if (res.ok) await cache.put(u, res);
    } catch (_) {
      return; // offline; try again next launch
    }
  }
}

self.addEventListener('message', (event) => {
  if (event.data === 'warm') event.waitUntil(warm());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const u = new URL(req.url);
  if (u.origin !== self.location.origin || !req.url.startsWith(self.registration.scope)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const key = req.mode === 'navigate' ? url('./') : u.origin + u.pathname;
    const hit = await cache.match(key, { ignoreSearch: true });
    if (hit) return hit;
    try {
      const res = await fetch(req);
      if (res.ok && res.type === 'basic') cache.put(key, res.clone());
      return res;
    } catch (e) {
      if (req.mode === 'navigate') {
        const shell = await cache.match(url('index.html'));
        if (shell) return shell;
      }
      throw e;
    }
  })());
});
