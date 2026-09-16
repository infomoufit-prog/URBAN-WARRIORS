import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const css=read('web/css/kombax-premium.css');
const hero=read('web/css/kombax-brand-heroes.css');
const gateway=read('web/js/modules/gateway.js');
const events=read('web/css/kombax-events.css');
const eventsJs=read('web/js/modules/kombax-events.js');
const index=read('web/index.html');
const checks=[
 ['gateway module-relative hero asset',gateway.includes("new URL('../../assets/brand-heroes/gateway-kombax-community.webp',import.meta.url).href")],
 ['gateway img uses resolved asset',gateway.includes('src="${esc(GATEWAY_HERO_IMAGE)}"')],
 ['gateway css fallback asset',css.includes("url('../assets/brand-heroes/gateway-kombax-community.webp')")],
 ['gateway smoke uses texture assets',css.includes("background-image:url('../assets/brand-heroes/smoke-texture-a.webp')") && css.includes("background-image:url('../assets/brand-heroes/smoke-texture-b.webp')")],
 ['gateway smoke visible tuning',css.includes('opacity:.34') && css.includes('gatewaySmokeRed 15s') && css.includes('gatewaySmokeBlue 18s')],
 ['social new hero asset exists',fs.existsSync(path.join(root,'web/assets/brand-heroes/hero-social.webp'))],
 ['social reframed for new image',hero.includes('--kx-hero-photo-position:79% 26%') && hero.includes('transform:scale(1.055) translate3d(-1.1%,0,0)')],
 ['social mobile crop updated',hero.includes('object-position:79% 18%!important')],
 ['shared smoke texture assets exist',fs.existsSync(path.join(root,'web/assets/brand-heroes/smoke-texture-a.webp')) && fs.existsSync(path.join(root,'web/assets/brand-heroes/smoke-texture-b.webp'))],
 ['brand heroes use texture smoke',hero.includes("--kx-hero-smoke-a:url('../assets/brand-heroes/smoke-texture-a.webp')") && hero.includes('mix-blend-mode:screen')],
 ['social smoke strengthened',hero.includes('--kx-hero-smoke-low:.16;--kx-hero-smoke-opacity:.32')],
 ['event hero safe organization rail',events.includes('Event hero organization safe area') && events.includes('max-width:min(43%,500px)') && events.includes('width:min(100%,470px)')],
 ['event hero supports more organizers',eventsJs.includes("groupedEntities(source,'organiza').slice(0,3)") && eventsJs.includes("groupedEntities(source,'avala').slice(0,3)")],
 ['urban warriors jiu-jitsu assets preserved',fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub'))],
 ['cache bust r10',revisionAtLeast(index,10)],
];
let bad=0; for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`); if(!ok) bad++;}
if(bad) process.exit(1); console.log('OK KOMBAX 20.101 R10 social hero + smoke hardening');
