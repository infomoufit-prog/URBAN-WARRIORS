import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const has=(txt,frag,msg=frag)=>assert.ok(txt.includes(frag),`Missing ${msg}`);
const not=(txt,frag,msg=frag)=>assert.ok(!txt.includes(frag),`Unexpected ${msg}`);
const tests=[];const test=(name,fn)=>tests.push([name,fn]);
const config=read('web/config.js'),gradle=read('android/app/build.gradle'),main=read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),sw=read('web/service-worker.js'),health=read('supabase/functions/health/index.ts'),index=read('web/index.html');
const showcase=read('web/js/modules/showcase.js'),events=read('web/js/modules/kombax-events.js'),repos=read('web/js/core/repositories.js'),analytics=read('web/js/ui/analytics-reports-r77.js'),css=read('web/css/kombax-analytics-r77.css'),appCss=read('web/css/app.css');
const m265=read('supabase/migrations/265_kombax_analytics_reports_r77.sql'),m266=read('supabase/migrations/266_kombax_report_payload_completeness_r77.sql'),m267=read('supabase/migrations/267_kombax_analytics_exact_range_r77.sql'),m268=read('supabase/migrations/268_kombax_report_exact_range_r77.sql'),edge=read('supabase/functions/kombax-report-r77/index.ts');

test('R77 analytics/reporting contract remains present in cumulative releases',()=>{has(m265,'app_kombax_showcase_analytics_r77');has(m265,'app_kombax_event_analytics_r77');has(edge,'kombax-reports');has(analytics,'kx-r77');});
test('R77 analytics stylesheet is loaded by the actual app shell',()=>has(index,'./css/kombax-analytics-r77.css?v=20133'));
test('Public Showcase product media is square and image-safe',()=>{has(appCss,'.showcase-item-visual{height:auto;aspect-ratio:1/1');has(appCss,'.showcase-item-visual>img{display:block;width:100%;height:100%;object-fit:contain');});
test('Private Showcase product cards have a 1:1 thumbnail and performance block',()=>{has(css,'.kx-showcase-product-thumb');has(css,'aspect-ratio:1/1');has(showcase,'kx-showcase-product-performance');has(showcase,'kx-showcase-product-thumb');});
test('Mi Showcase exposes the premium navigation areas without replacing existing seller tools',()=>{for(const id of ['summary','products','orders','stock','analytics','reports','finance','commerce','settings'])has(showcase,`data-showcase-nav="${id}"`);has(showcase,'kx-showcase-private-nav');has(showcase,'kx-seller-tools');});
test('Explore Showcase remains a distinct public route',()=>{has(showcase,"activeView='catalog'");has(showcase,'openPublicShowcaseRoute');has(showcase,'openPrivateShowcaseRoute');has(showcase,'Public exploration is intentionally independent');});
test('Showcase analytics use provider-scoped private RPCs',()=>{has(repos,"app_kombax_showcase_analytics_r77");has(repos,"app_kombax_showcase_analytics_range_r77");has(m265,"SHOWCASE_MANAGEMENT_REQUIRED");has(m267,"SHOWCASE_MANAGEMENT_REQUIRED");});
test('Events analytics use event-scoped private RPCs',()=>{has(repos,"app_kombax_event_analytics_r77");has(repos,"app_kombax_event_analytics_range_r77");has(m265,"EVENT_MANAGE_REQUIRED");has(m267,"EVENT_MANAGE_REQUIRED");});
test('Calendar and custom periods are first-class controls',()=>{for(const frag of ["'month'","'prev_month'","'custom'",'periodCurrentMonth','periodPreviousMonth','periodCustom','data-r77-from','data-r77-to'])has(analytics,frag);});
test('Exact range analytics compare the immediately preceding equal window',()=>{has(m267,'v_prev_from timestamptz := p_from - (p_to-p_from)');has(m267,"'previous'");});
test('Showcase analytics expose histogram categories and per-product performance',()=>{has(analytics,'kx-r77-histogram');has(analytics,'categoryBars');has(analytics,'productTable');has(m267,"'conversion_percent'");});
test('Analytics UI contains responsive premium breakpoints',()=>{for(const bp of ['@media(max-width:1100px)','@media(max-width:820px)','@media(max-width:620px)','@media(max-width:430px)'])has(css,bp);has(css,'.kx-r77-custom-period');});
test('Reports use one reusable KOMBAX Reports Edge Function for both modules',()=>{has(repos,"invokeFunction('kombax-report-r77'");has(edge,"scope=body.scope==='event'?'event':body.scope==='showcase'?'showcase':''");});
test('Exact report payload aligns with the exact analytics period',()=>{has(edge,"app_kombax_report_payload_range_r77");has(m268,'app_kombax_showcase_analytics_range_r77');has(m268,'app_kombax_event_analytics_range_r77');});
test('R77 private report RPCs deny anon and PUBLIC while granting authenticated',()=>{for(const m of [m265,m266,m267,m268]){has(m,'revoke all on function');has(m,'authenticated');}has(m268,"set search_path=''");});
test('Generated reports are stored in a private PDF-only bucket with signed links',()=>{has(m266,"'kombax-reports'");has(m266,'public=false');has(m266,"'application/pdf'");has(edge,"createSignedUrl(path,600)");});
test('Showcase PDF uses seller branding and real product thumbnails',()=>{has(edge,'e.logo_url');has(edge,'q.image_url');has(edge,'drawImage(im');has(edge,"scope==='showcase'");});
test('Events PDF uses organizer branding poster and professional results',()=>{has(edge,'e.poster_url');has(edge,'e.organizer');has(edge,'extra.results');has(edge,'r.ganador_participante_id');has(edge,'r.metodo_resultado');});
test('Events Center exposes Analytics Results and Reports as independent tools',()=>{has(events,"eventOpsTool('stats',t('events.analytics.title')");has(events,"eventOpsTool('results',t('events.results.title')");has(events,"eventOpsTool('reports',t('events.reports.title')");});
test('Events results navigation only renders stored result fields',()=>{has(events,'ganador_participante_id===r.participante_a_id');has(events,'r.metodo_resultado');has(events,'r.asalto');has(events,'r.tiempo_resultado');not(events,'Math.random()');});
test('Report operational rows minimize buyer PII',()=>{not(m268,'buyer_email');not(m268,'shipping_phone');not(m268,'shipping_address');has(m268,'order_number');});
test('Commerce entitlement remains separate from Stripe seller readiness',()=>{has(showcase,'Commerce es un derecho comercial separado');has(showcase,'checkoutAvailable');has(showcase,'sellerAccountActive');});
test('Events publication remains separate from Ticketing activation',()=>{has(events,'El evento puede publicarse y medirse sin Ticketing');has(events,'Activación independiente por evento');});
test('All eight locales contain the R77 exact-period UI keys',()=>{for(const lang of ['es','en','fr','pt','it','de','th','fil']){const c=read(`web/js/i18n/locales/${lang}/common.js`);for(const k of ['periodCurrentMonth','periodPreviousMonth','periodCustom','applyPeriod','invalidPeriod'])has(c,`"${k}"`);}});

let passed=0;for(const [name,fn] of tests){try{fn();console.log(`✓ ${name}`);passed++;}catch(e){console.error(`✗ ${name}`);console.error(e.message);}}
console.log(`\nKOMBAX R77 PREMIUM ANALYTICS & REPORTS: ${passed}/${tests.length} PASS`);if(passed!==tests.length)process.exit(1);
