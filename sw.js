/* IronLog service worker: la app funciona sin conexión.
   Estrategia: "stale-while-revalidate" (sirve la copia guardada al instante y actualiza en segundo plano).
   Las llamadas a Supabase NUNCA se cachean. */
const CACHE = 'ironlog-v1';
const CORE = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/icon-maskable-512.png',
  './icons/apple-touch-icon.png'
];
const CDN = [
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js',
  'https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(CORE);
    // Las librerías CDN se intentan cachear, pero si fallan no bloquean la instalación.
    await Promise.all(CDN.map(async (url) => {
      try { const r = await fetch(url, { mode: 'cors' }); if (r.ok) await cache.put(url, r); } catch (e) { /* sin red */ }
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in')) return; // datos: siempre red
  const sameOrigin = url.origin === self.location.origin;
  const allowed = sameOrigin || ['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'].includes(url.hostname);
  if (!allowed) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const isNav = req.mode === 'navigate';
    const cached = await cache.match(req, { ignoreSearch: sameOrigin }) || (isNav ? await cache.match('./index.html') : undefined);
    const network = fetch(req).then((res) => {
      if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone()).catch(() => {});
      return res;
    }).catch(() => undefined);
    if (cached) { event.waitUntil(network); return cached; }
    const res = await network;
    if (res) return res;
    return new Response('Sin conexión', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
  })());
});
