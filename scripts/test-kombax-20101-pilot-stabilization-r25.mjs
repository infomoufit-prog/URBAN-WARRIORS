import fs from 'node:fs';

const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const events=read('web/js/modules/kombax-events.js');
const components=read('web/js/ui/components.js');
const showcase=read('web/js/modules/showcase.js');
const css=read('web/css/kombax-events.css');
const pkg=read('package.json');

const checks=[];
const check=(name,ok)=>{checks.push([name,Boolean(ok)]);console.log(`${ok?'PASS':'FAIL'} · ${name}`);};

check('R23 audit plan exists',fs.existsSync(new URL('../docs/07_QA_AUDITS/R23_AUDIT_PLAN.md',import.meta.url)));
check('R23 audit report exists',fs.existsSync(new URL('../docs/07_QA_AUDITS/R23_AUDIT_REPORT.md',import.meta.url)));
check('R25 implementation plan exists',fs.existsSync(new URL('../docs/06_HISTORY/PLANS/PHASE_20101_R25_IMPLEMENTATION_PLAN.md',import.meta.url)));
check('interest captures currentTarget before await',/async eventClick=>\{\s*const button=eventClick\.currentTarget/.test(events));
check('interest never dereferences currentTarget after await',!events.includes("button.currentTarget.textContent=next==='none'?'Me interesa':'Guardado'"));
check('interest keeps icon and updates dedicated label',events.includes('data-kx-event-interest-label')&&events.includes("label.textContent=next==='none'?'Me interesa':'Guardado'"));
check('interest prevents duplicate submit',events.includes("button.dataset.kxBusy==='1'")&&events.includes("button.dataset.kxBusy='1'"));
check('external media handler captures stable button',events.includes("const button=eventClick.currentTarget;const url=safeExternal"));
check('Showcase save handler captures stable button',showcase.includes("const button=e.currentTarget;if(button.dataset.kxBusy==='1')return"));
check('modal emits lifecycle close event',components.includes("dispatchEvent(new CustomEvent('kx:modal-before-close'))"));
check('media hydrator subscribes lifecycle cleanup',events.includes("addEventListener?.('kx:modal-before-close',cleanup,{once:true})"));
check('media hydrator decodes image before DOM replacement',events.includes('await waitForEventImageReady(media);')&&events.indexOf('await waitForEventImageReady(media);')<events.indexOf('stage.replaceChildren(media);',events.indexOf('await waitForEventImageReady(media);')));
check('media hydrator is idempotent/inflight guarded',events.includes("card.dataset.kxHydrated==='1'")&&events.includes('const jobs=new WeakMap()'));
check('no forced 1400ms album hydrate-all',!events.includes('},1400)')&&!events.includes('1400);});'));
check('viewport prefetch remains bounded by observer',events.includes("rootMargin:'640px 0px'"));
const openEventStart=events.indexOf('async function openEvent(id');
const openEventSlice=events.slice(openEventStart,events.indexOf('function participantOptions',openEventStart));
check('openEvent media hydration is non-blocking',openEventSlice.includes('void hydrateEventMedia(wrap);')&&!openEventSlice.includes('await hydrateEventMedia(wrap)'));
check('event detail cache is bounded',events.includes('const EVENT_DETAIL_CACHE_MAX=24')&&events.includes('while(eventDetailCache.size>EVENT_DETAIL_CACHE_MAX)'));
check('mobile event detail removes backdrop blur',css.includes('.kx-event-detail-layer{background:#050608!important;backdrop-filter:none!important;-webkit-backdrop-filter:none!important}'));
check('mobile Fight Card image filters/transitions disabled',css.includes('.kx-event-detail-modal .kx-main-fighter-photo img,.kx-event-detail-modal .kx-fight-photo img{filter:none!important;transition:none!important}'));
check('mobile card animations reduced',css.includes('.kx-event-detail-modal .kx-main-versus>b,.kx-event-detail-modal .kx-fight-vs b,.kx-event-detail-modal .kx-fight-state.en_curso{animation:none!important}'));
check('R25 does not introduce R24 backend RPC names',!events.includes('v192')&&!events.includes('v193'));
check('R22 keyset preserved',events.includes('listPage')||read('web/js/core/repositories.js').includes('app_kombax_eventos_publicos_page_v191'));
check('R23 fighter resolver preserved',events.includes('URBAN_DEMO_FIGHTER_LOCAL')&&events.includes('resolvedFighterPhoto'));
check('package registers R25 test',pkg.includes('test-kombax-20101-pilot-stabilization-r25.mjs'));

const pass=checks.filter(([,ok])=>ok).length;
console.log(`R25 ${pass}/${checks.length}`);
if(pass!==checks.length)process.exit(1);
