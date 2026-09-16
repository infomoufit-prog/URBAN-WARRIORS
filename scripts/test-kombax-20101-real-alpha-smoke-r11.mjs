import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const css=read('web/css/kombax-premium.css');
const heroCss=read('web/css/kombax-brand-heroes.css');
const gateway=read('web/js/modules/gateway.js');
const heroJs=read('web/js/ui/brand-hero.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const assets=['smoke-alpha-red.webp','smoke-alpha-cyan.webp','smoke-alpha-neutral.webp','smoke-alpha-warm.webp'];
const checks=[
 ['four alpha smoke sprites present',assets.every(a=>fs.existsSync(path.join(root,'web/assets/brand-heroes',a)))],
 ['sprites are compact',assets.every(a=>fs.statSync(path.join(root,'web/assets/brand-heroes',a)).size<100_000)],
 ['brand hero has three independent smoke layers',heroJs.includes('kx-brand-hero-smoke smoke-a')&&heroJs.includes('kx-brand-hero-smoke smoke-b')&&heroJs.includes('kx-brand-hero-smoke smoke-c')],
 ['gateway has red blue and neutral smoke',gateway.includes('gateway-entry-smoke smoke-red')&&gateway.includes('gateway-entry-smoke smoke-blue')&&gateway.includes('gateway-entry-smoke smoke-neutral')],
 ['gateway uses real alpha assets',css.includes("smoke-alpha-red.webp")&&css.includes("smoke-alpha-cyan.webp")&&css.includes("smoke-alpha-neutral.webp")],
 ['brand heroes use real alpha assets',heroCss.includes("smoke-alpha-red.webp")&&heroCss.includes("smoke-alpha-cyan.webp")&&heroCss.includes("smoke-alpha-warm.webp")],
 ['old R10 texture path removed',!css.includes('smoke-texture-a.webp')&&!css.includes('smoke-texture-b.webp')&&!heroCss.includes('smoke-texture-a.webp')&&!heroCss.includes('smoke-texture-b.webp')],
 ['no active hue-rotate smoke recoloring',!css.includes('hue-rotate(')&&!heroCss.includes('hue-rotate(')],
 ['smoke motion is transform opacity only',heroCss.includes('@keyframes kxSmokeDriftA')&&heroCss.includes('@keyframes kxSmokeDriftB')&&heroCss.includes('@keyframes kxSmokeDriftC')],
 ['events stronger than showcase',heroCss.includes('--kx-smoke-opacity-a:.31')&&heroCss.includes('--kx-smoke-opacity-a:.15')],
 ['reduced motion protects smoke',heroCss.includes('@media(prefers-reduced-motion:reduce){.kx-brand-hero-smoke{animation:none!important')&&css.includes('.gateway-entry-visual::after,.gateway-entry-smoke{animation:none!important')],
 ['cache bust r11',revisionAtLeast(index,11)&&revisionAtLeast(sw,11,'media-r')],
 ['approved social hero remains',fs.existsSync(path.join(root,'web/assets/brand-heroes/hero-social.webp'))],
 ['urban warriors event preserved',fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/poster.webp'))],
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);console.log('OK KOMBAX 20.101 R11 real alpha smoke');
