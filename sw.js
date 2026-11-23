/* IronLog service worker: la app funciona sin conexión.
   - La página (HTML): primero la red (sin caché HTTP) para tener siempre la última versión;
     si no hay red o tarda más de 4 s, la copia guardada.
   - Librerías, iconos y fuentes: copia guardada al instante y actualización en segundo plano.
   - Supabase y Gemini NUNCA se cachean. */
const CACHE = 'ironlog-v3';
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
  if (url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in') || url.hostname.endsWith('googleapis.com') && url.hostname !== 'fonts.googleapis.com') return; // datos: siempre red
  const sameOrigin = url.origin === self.location.origin;
  const allowed = sameOrigin || ['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'].includes(url.hostname);
  if (!allowed) return;

  const isPage = req.mode === 'navigate' || (sameOrigin && /\/(index\.html)?$/.test(url.pathname));
  if (isPage) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      const net = fetch(req, { cache: 'no-cache' }).then((res) => {
        if (res && res.ok) cache.put('./index.html', res.clone()).catch(() => {});
        return res;
      });
      const timeout = new Promise((r) => setTimeout(() => r(null), 4000));
      try {
        const res = await Promise.race([net, timeout]);
        if (res && res.ok) return res;
      } catch (e) { /* sin red */ }
      const cached = await cache.match('./index.html');
      if (cached) { event.waitUntil(net.catch(() => {})); return cached; }
      try { return await net; } catch (e) { return new Response('Sin conexión', { status: 503, headers: { 'Content-Type': 'text/plain; charset=utf-8' } }); }
    })());
    return;
  }
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const isNav = false;
    const cached = await cache.match(req, { ignoreSearch: sameOrigin });
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
