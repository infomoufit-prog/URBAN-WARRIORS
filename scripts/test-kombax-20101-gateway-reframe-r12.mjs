import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const css=read('web/css/kombax-premium.css');
const heroCss=read('web/css/kombax-brand-heroes.css');
const gateway=read('web/js/modules/gateway.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const checks=[
 ['gateway visual widened',css.includes("width:min(69%,860px)")],
 ['gateway image reframed and rescaled',css.includes("background:#07090c url('../assets/brand-heroes/gateway-kombax-community.webp') 56% 46%/cover no-repeat") && css.includes('object-fit:cover') && css.includes('object-position:56% 46%') && css.includes('transform:scale(1.085) translate3d(2.2%,-1%,0)')],
 ['gateway overlay softened',css.includes('opacity:.46;animation:gatewayAtmospherePulse')],
 ['gateway smoke reduced for image with built-in atmosphere',css.includes("smoke-red{left:4%;bottom:22%;width:60%;height:34%;background-image:url('../assets/brand-heroes/smoke-alpha-red.webp');opacity:.12") && css.includes("smoke-blue{right:-3%;top:27%;width:55%;height:31%;background-image:url('../assets/brand-heroes/smoke-alpha-cyan.webp');opacity:.11") && css.includes("smoke-neutral{left:34%;top:10%;width:58%;height:30%;background-image:url('../assets/brand-heroes/smoke-alpha-neutral.webp');opacity:.05")],
 ['mobile gateway crop updated',(css.includes('background-position:54% 24%') && css.includes('object-position:54% 24%') && css.includes('transform:scale(1.03)'))||(css.includes('background-position:52% 23%')&&css.includes('object-position:52% 23%')&&css.includes('transform:scale(1.01)'))],
 ['gateway markup still uses three smoke spans',gateway.includes('gateway-entry-smoke smoke-red')&&gateway.includes('gateway-entry-smoke smoke-blue')&&gateway.includes('gateway-entry-smoke smoke-neutral')],
 ['brand heroes smoke system still present',heroCss.includes('kx-brand-hero-smoke smoke-a') || read('web/js/ui/brand-hero.js').includes('kx-brand-hero-smoke smoke-a')],
 ['social hero preserved',fs.existsSync(path.join(root,'web/assets/brand-heroes/hero-social.webp'))],
 ['urban warriors event assets preserved',fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp'))],
 ['cache bust r12',revisionAtLeast(index,12)&&revisionAtLeast(sw,12,'media-r')],
];
let bad=0;
for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`); if(!ok) bad++;}
if(bad) process.exit(1);
console.log('OK KOMBAX 20.101 R12 gateway reframe final');
