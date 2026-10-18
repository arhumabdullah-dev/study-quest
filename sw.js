// Offline support: serve the latest copy from the network, fall back to the cache when offline.
// Bump VERSION whenever files change so phones drop the old cache.
const VERSION = 'v2';
const FILES = ['./', './index.html', './stress.html', './study.webmanifest', './stress.webmanifest',
  './icons/study-180.png', './icons/study-192.png', './icons/study-512.png',
  './icons/stress-180.png', './icons/stress-192.png', './icons/stress-512.png',
  './img/anren/blush.webp',
  './img/anren/chubby.webp',
  './img/anren/eat.webp',
  './img/anren/happy.webp',
  './img/anren/hungry.webp',
  './img/anren/hurt.webp',
  './img/anren/idle.webp',
  './img/anren/kiss.webp',
  './img/anren/left.webp',
  './img/anren/remind.webp',
  './img/anren/right.webp',
  './img/anren/sleepy.webp',
  './img/anren/sulk.webp',
  './img/stickers/angry.webp',
  './img/stickers/chin.webp',
  './img/stickers/shock.webp',
  './img/stickers/smug.webp'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if(e.request.method !== 'GET' || new URL(e.request.url).origin !== location.origin) return;
  e.respondWith(
    fetch(e.request).then(res => {
      const copy = res.clone();
      caches.open(VERSION).then(c => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request, {ignoreSearch: true}))
  );
});
