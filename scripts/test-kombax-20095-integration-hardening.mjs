import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20095 INTEGRATION HARDENING: ${msg}`);console.log(`OK 20095: ${msg}`)};
const [config,sw,index,events,app,repo,main,gradle,manifest,network,netlify,health,gateway,css]=await Promise.all([
  read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/modules/kombax-events.js'),read('web/js/app.js'),read('web/js/core/repositories.js'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('android/app/build.gradle'),read('android/app/src/main/AndroidManifest.xml'),read('android/app/src/main/res/xml/network_security_config.xml'),read('netlify.toml'),read('supabase/functions/health/index.ts'),read('web/js/modules/gateway.js'),read('web/css/kombax-events.css')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20095&&a>=20095&&w>=20095&&h>=20095,'identidad 20095 o superior consistente en web/PWA/Android/health local');
assert(/v=20(?:095|09[6-9]|1\d{2})/.test(index)&&!index.includes('v=20094'),'cache-busting principal conserva 20095 o superior');
assert(main.includes('appendEntryParam(query, data, "event"')&&main.includes('appendEntryParam(query, data, "fight"'),'Android conserva event/fight de enlaces KOMBAX');
assert(main.includes('[A-Za-z0-9][A-Za-z0-9-]{0,119}')&&main.includes('[1-5][A-Fa-f0-9]{3}-[89AaBb]'),'event slug y fight UUID se validan antes de entrar al WebView');
assert(main.includes('trustedKombaxHost(data.getHost())')&&main.includes('"kombax.es".equalsIgnoreCase(host)')&&main.includes('"www.kombax.es".equalsIgnoreCase(host)'),'Android restringe deep-links a hosts KOMBAX');
assert(app.indexOf("entryParams.get('event')")<app.indexOf('backend.restore()'),'landing pública de Evento se resuelve antes de restaurar sesión');
assert(app.includes('renderPublicKombaxEventLanding(publicEventSlug')&&repo.includes("backend.publicRpc('app_kombax_evento_publico_slug_v166'"),'deep-link público sigue sin exigir login');
assert(((events.includes("media.addEventListener('error',()=>hydrateCard"))||(events.includes('const attempts=local?1:2')&&events.includes('for(let attempt=0;attempt<attempts;attempt+=1)')&&events.includes('await repos.kombaxEvents.mediaUrl(card.dataset.kxEventMedia)')))&&events.includes('Reintentar')&&events.includes('const fresh=await repos.kombaxEvents.mediaUrl'),'media firmada renueva URL ante error y al descargar');
assert(!/\bfetch\s*\(/.test(events),'UI Eventos mantiene transporte centralizado sin fetch directo');
assert(sw.includes("if(url.origin!==self.location.origin)return")&&!sw.includes('event-media-url'),'service worker no persiste URLs firmadas externas');
assert(netlify.includes('from = "/*"')&&netlify.includes('to = "/index.html"')&&netlify.includes('status = 200'),'Netlify mantiene fallback SPA para deep-links con query');
assert(netlify.includes("connect-src 'self' https://poggsobhtutbuagjiydc.supabase.co wss://poggsobhtutbuagjiydc.supabase.co")&&netlify.includes("media-src 'self' blob: https:"),'CSP permite backend/media HTTPS sin abrir object/frame');
assert(manifest.includes('android:usesCleartextTraffic="false"')&&network.includes('cleartextTrafficPermitted="false"'),'Android prohíbe tráfico cleartext');
assert(main.includes('settings.setAllowFileAccess(false)')&&main.includes('settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW)'),'WebView mantiene aislamiento de archivos y mixed-content');
assert(manifest.includes('android:autoVerify="false"'),'App Links verificados quedan deliberadamente pendientes del fingerprint Play/Digital Asset Links');
assert(gateway.includes("id:'espectador'")&&gateway.includes('disabled:true'),'perfil Espectador continúa cerrado');
assert(css.includes('kx-event-media-unavailable'),'UX de degradación de media tiene estado explícito');
console.log('PASS 20095 KOMBAX Integration / Hardening Final Candidate');
