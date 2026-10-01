// historical-release-marker: const BUILD_MARKER='kombax-build-20161'; const VERSION='kombax-2.0.0-rc13-20161-r108-finance-guide-poster';
// historical-release-marker: kombax-build-20134 20134-r81-tap-to-pay
// historical cache marker: 20110-r60
// historical cache marker: media-r34
// historical cache marker: media-r331
// historical cache marker: media-r29
// historical cache marker: media-r28
// historical cache marker: media-r27
const BUILD_MARKER='kombax-build-20169';
const VERSION='kombax-2.0.0-rc13-20169-r116-golden-pilot-freeze';
// historical cache marker: media-r36
// historical cache marker: media-r37
// historical cache marker: media-r38
// historical cache marker: media-r39
const STATIC_CACHE=`${VERSION}-media-r44`; // historical cache marker: media-r40; media-r41; media-r42; media-r43
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key!==STATIC_CACHE)await caches.delete(key);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{
  const req=event.request;if(req.method!=='GET')return;const url=new URL(req.url);if(url.origin!==self.location.origin)return;
  // Nunca cachear HTML, JS, CSS o config: evita que una versión antigua oculte correcciones.
  if(req.mode==='navigate'||/\.(?:js|css|html)$/.test(url.pathname)||url.pathname.endsWith('/config.js')||url.pathname.endsWith('/service-worker.js')){event.respondWith(fetch(req,{cache:'no-store'}));return;}
  if(req.destination==='image'||url.pathname.includes('/assets/'))event.respondWith((async()=>{const cache=await caches.open(STATIC_CACHE);const hit=await cache.match(req);if(hit)return hit;const res=await fetch(req);if(res.ok)cache.put(req,res.clone());return res;})());
});
