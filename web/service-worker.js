const VERSION='uw2-2.0.0-rc13-20057';
const STATIC_CACHE=`${VERSION}-media`;
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key!==STATIC_CACHE)await caches.delete(key);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{
  const req=event.request;if(req.method!=='GET')return;const url=new URL(req.url);if(url.origin!==self.location.origin)return;
  // Nunca cachear HTML, JS, CSS o config: evita que una versión antigua oculte correcciones.
  if(req.mode==='navigate'||/\.(?:js|css|html)$/.test(url.pathname)||url.pathname.endsWith('/config.js')||url.pathname.endsWith('/service-worker.js')){event.respondWith(fetch(req,{cache:'no-store'}));return;}
  if(req.destination==='image'||url.pathname.includes('/assets/'))event.respondWith((async()=>{const cache=await caches.open(STATIC_CACHE);const hit=await cache.match(req);if(hit)return hit;const res=await fetch(req);if(res.ok)cache.put(req,res.clone());return res;})());
});
