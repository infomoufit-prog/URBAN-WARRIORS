const CACHE = 'urban-warriors-v1.6.0-build12';
const ASSETS = [
  './', './index.html', './config.js?v=1.6.0-b12', './manifest.webmanifest', './css/app.css?v=1.6.0-b12',
  './js/demo-data.js?v=1.6.0-b12', './js/data-store.js?v=1.6.0-b12', './js/push.js?v=1.6.0-b12', './js/app.js?v=1.6.0-b12',
  './assets/urban-warriors-logo.png', './assets/icons/icon-192.png', './assets/icons/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  // Nunca interceptar Supabase, Firebase ni ningún API externo. La caché de la PWA
  // es exclusivamente para assets del mismo origen.
  if (url.origin !== self.location.origin) return;

  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => response)
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  event.respondWith(
    fetch(event.request).then((response) => {
      if (response.ok) {
        const clone = response.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, clone));
      }
      return response;
    }).catch(() => caches.match(event.request))
  );
});
