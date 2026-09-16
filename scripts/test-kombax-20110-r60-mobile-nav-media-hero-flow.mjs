import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [stab,premium,hero,components,profile,gateway,events]=await Promise.all([
  read('web/css/kombax-ui-stabilization-r60.css'),read('web/css/kombax-premium.css'),read('web/css/kombax-brand-heroes.css'),
  read('web/js/ui/components.js'),read('web/js/modules/public-profile.js'),read('web/js/modules/gateway.js'),read('web/js/modules/kombax-events.js')
]);
const checks=[
  ['mobile bottom navigation hidden',/\.bottom-nav\{display:none!important\}/.test(stab)],
  ['mobile content no longer reserves tabbar height',/padding-bottom:calc\(var\(--uw-safe-bottom\) \+ 28px\)!important/.test(stab)],
  ['toast respects system bottom inset without tabbar',/\.toast\{bottom:calc\(var\(--uw-safe-bottom\) \+ 16px\)!important\}/.test(stab)],
  ['generic immersive media viewer exported',/export function openImmersiveMedia\(/.test(components)],
  ['immersive layer preserves underlying modal',/kx-immersive-media-layer/.test(components)&&!/export function openImmersiveMedia[\s\S]{0,220}closeModal\(\)/.test(components)],
  ['immersive media CSS covers viewport',/\.kx-immersive-media-layer\{position:fixed;inset:0;z-index:2600/.test(premium)],
  ['public profile photos and videos can expand',/data-kx-public-video/.test(profile)&&/openProfileAlbumMedia/.test(profile)&&/data-kx-public-photo/.test(profile)],
  ['member album video expand control exists',/data-kx-member-video-open/.test(profile)],
  ['direct profile album photos and videos can expand',/data-kx-direct-video-open/.test(gateway)&&/openImmersiveMedia/.test(gateway)],
  ['events portrait focal point keeps both faces',/kx-brand-hero-events \.kx-brand-hero-photo\{object-position:68% 15%!important\}/.test(hero)],
  ['social portrait focal point centers fighter',/kx-brand-hero-social \.kx-brand-hero-photo\{object-position:70% 15%!important\}/.test(hero)],
  ['event detail request is deduplicated',/eventDetailInflight=new Map\(\)/.test(events)&&/if\(existing\)return existing/.test(events)],
  ['event detail is prefetched before click',/pointerenter/.test(events)&&/pointerdown/.test(events)&&/prefetchEventDetail/.test(events)],
  ['event loading feedback is delayed, not a page reload',/EVENT_OPEN_FEEDBACK_DELAY_MS=120/.test(events)&&/Preparando la ficha sin recargar la cartelera/.test(events)],
  ['event preparation leaves first-paint critical path',/void hydrateEventPreparationRows\(wrap,event,participants,eventName,openSeq\)/.test(events)],
  ['event discovery preserves cached cards',/if\(cached.length\)\{renderList\(\);restoreEventsScroll\(\);\}/.test(events)],
];
for(const [name,ok] of checks){assert.equal(ok,true,name);console.log(`PASS ${name}`)}
console.log(`OK ${checks.length}/${checks.length} R60 mobile nav + media fullscreen + hero focus + Events flow`);
