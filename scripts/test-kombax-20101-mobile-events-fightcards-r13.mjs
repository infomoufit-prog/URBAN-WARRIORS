import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const events=read('web/js/modules/kombax-events.js');
const eventCss=read('web/css/kombax-events.css');
const heroCss=read('web/css/kombax-brand-heroes.css');
const gatewayCss=read('web/css/kombax-premium.css');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const smokeAssets=['smoke-alpha-red.webp','smoke-alpha-cyan.webp','smoke-alpha-neutral.webp','smoke-alpha-warm.webp'];
const checks=[
 ['fight card section sorts and counts fights',events.includes('kx-event-fights-prominent')&&events.includes('data-kx-fight-count')&&events.includes("sort((a,b)=>(Number(a.orden)||999)-(Number(b.orden)||999))")],
 ['fight cards appear before info blocks',events.indexOf('<section id="kx-event-fight-card">${fightsSection(event,fights)}</section>')<events.indexOf('${eventInfoExperience(event)}')],
 ['fight card has no template-image dependency',events.includes('kx-fight-card-surface')&&!events.includes('<img class="kx-fight-card-bg" src="./assets/events/templates/fight-card-square.svg"')],
 ['fighter image fallback binding exists',events.includes('function bindFightImageFallbacks')&&events.includes("img.dataset.kxFallback==='1'")&&events.includes('bindFightImageFallbacks(wrap)')&&events.includes('bindFightImageFallbacks(document)')],
 ['fight grid forced visible',eventCss.includes('display:grid!important;visibility:visible!important;opacity:1!important')],
 ['mobile fight cards are one-column and compact',eventCss.includes('@media(max-width:760px){.kx-event-fights-prominent')&&eventCss.includes('.kx-fight-card.compact{min-height:300px}')],
 ['mobile brand hero media is shallower to reduce zoom',heroCss.includes('.kx-brand-hero-media{inset:0 0 auto 0;height:61%;transform:none!important;animation:none!important')],
 ['mobile Social crop reduced',heroCss.includes('.kx-brand-hero-social .kx-brand-hero-photo{object-position:68% 18%!important;transform:none!important}')],
 ['mobile Events crop reduced',heroCss.includes('.kx-brand-hero-events .kx-brand-hero-photo{object-position:50% 18%!important;transform:none!important}')],
 ['mobile Showcase crop reduced',heroCss.includes('.kx-brand-hero-showcase .kx-brand-hero-photo{object-position:60% 18%!important;transform:none!important}')],
 ['gateway mobile image blends into copy',gatewayCss.includes('margin:0 -4px -82px')&&gatewayCss.includes('mask-image:linear-gradient')&&gatewayCss.includes('padding:86px 2px 2px;background:linear-gradient')],
 ['gateway mobile smoke is restrained',gatewayCss.includes('smoke-red{opacity:.08}')&&gatewayCss.includes('smoke-blue{opacity:.07}')&&gatewayCss.includes('smoke-neutral{opacity:.025}')],
 ['real alpha smoke preserved',smokeAssets.every(a=>fs.existsSync(path.join(root,'web/assets/brand-heroes',a)))&&!heroCss.includes('smoke-texture-a.webp')&&!heroCss.includes('hue-rotate(')],
 ['Urban Warriors event assets preserved',fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp'))],
 ['R13 cache bust',revisionAtLeast(index,13)&&revisionAtLeast(sw,13,'media-r')]
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);console.log('OK KOMBAX 20.101 R13 mobile UX + Fight Cards');
