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
 ['gateway specificity fix',css.includes('.gateway-brand-stage>.gateway-entry-visual{position:absolute;z-index:1')],
 ['gateway module-relative hero asset',gateway.includes("new URL('../../assets/brand-heroes/gateway-kombax-community.webp',import.meta.url).href")],
 ['gateway img uses resolved asset',gateway.includes('src="${esc(GATEWAY_HERO_IMAGE)}"')],
 ['gateway css fallback asset',css.includes("url('../assets/brand-heroes/gateway-kombax-community.webp')")],
 ['gateway smoke visible',css.includes('opacity:.40') && css.includes('gatewaySmokeRed 13.5s') && css.includes('gatewaySmokeBlue 16s')],
 ['legacy watermark disabled',css.includes('.gateway-brand-stage>.gateway-brand-watermark{display:none!important}')],
 ['social reframed',hero.includes('--kx-hero-photo-position:76% 30%') && hero.includes('transform:scale(1.125) translate3d(-3.2%,1.2%,0)')],
 ['social mobile crop',hero.includes('object-position:76% 18%!important')],
 ['social smoke visible',hero.includes('--kx-hero-smoke-low:.14;--kx-hero-smoke-opacity:.25')],
 ['event hero safe organization rail',events.includes('Event hero organization safe area') && events.includes('max-width:min(43%,500px)') && events.includes('width:min(100%,470px)')],
 ['event hero supports more organizers',eventsJs.includes("groupedEntities(source,'organiza').slice(0,3)") && eventsJs.includes("groupedEntities(source,'avala').slice(0,3)")],
 ['cache bust r9',revisionAtLeast(index,9)],
 ['hero asset exists',fs.existsSync(path.join(root,'web/assets/brand-heroes/gateway-kombax-community.webp'))],
 ['social asset exists',fs.existsSync(path.join(root,'web/assets/brand-heroes/hero-social.webp'))],
];
let bad=0; for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`); if(!ok) bad++;}
if(bad) process.exit(1); console.log('OK KOMBAX 20.101 R9 visual hero correction');
