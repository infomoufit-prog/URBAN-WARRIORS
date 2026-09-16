import fs from "node:fs";
import path from "node:path";
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),"utf8");
const heroCss=read("web/css/kombax-brand-heroes.css");
const gatewayCss=read("web/css/kombax-premium.css");
const index=read("web/index.html");
const sw=read("web/service-worker.js");
const checks=[
 ["tablet brand hero tuning exists",heroCss.includes("@media(min-width:621px) and (max-width:1024px){")&&heroCss.includes(".kx-brand-hero-social{--kx-hero-photo-position:74% 24%;--kx-hero-media-scale:1.01}")],
 ["mobile brand hero tuning reduces zoom further",heroCss.includes(".kx-brand-hero{min-height:620px}")&&heroCss.includes(".kx-brand-hero-media{height:56%}")&&heroCss.includes(".kx-brand-hero-social .kx-brand-hero-photo{object-position:64% 15%!important}")&&heroCss.includes(".kx-brand-hero-events .kx-brand-hero-photo{object-position:52% 15%!important}")&&heroCss.includes(".kx-brand-hero-showcase .kx-brand-hero-photo{object-position:58% 15%!important}")],
 ["landscape phone hero tuning exists",heroCss.includes("@media(max-width:900px) and (orientation:landscape){")&&heroCss.includes(".kx-brand-hero-media{inset:0 0 0 34%;height:auto;transform:none!important;animation:none!important}")],
 ["tablet gateway tuning exists",gatewayCss.includes("@media(min-width:621px) and (max-width:1024px){")&&gatewayCss.includes(".gateway-brand-stage>.gateway-entry-visual{width:min(64%,720px);right:-1%}")],
 ["mobile gateway image fuses better with copy",gatewayCss.includes("height:clamp(258px,71vw,320px);margin:0 -6px -108px")&&gatewayCss.includes("padding:110px 4px 4px;background:linear-gradient(180deg,transparent 0%,rgba(8,10,13,.28) 21%,#080a0d 57%)")],
 ["mobile gateway smoke is even more restrained",gatewayCss.includes(".gateway-entry-smoke.smoke-red{opacity:.05}")&&gatewayCss.includes(".gateway-entry-smoke.smoke-blue{opacity:.05}")&&gatewayCss.includes(".gateway-entry-smoke.smoke-neutral{opacity:.018}")],
 ["landscape gateway tuning exists",gatewayCss.includes("@media(max-width:900px) and (orientation:landscape){")&&gatewayCss.includes(".gateway-brand-stage>.gateway-entry-visual{height:210px;margin:0 -4px -72px}")],
 ["cache bust R15",revisionAtLeast(index,15)&&revisionAtLeast(sw,15,'media-r')],
 ["R14 creator preserved",/EVENT CREATOR · R(?:14|1[5-9]|2\d)/.test(read("web/js/modules/kombax-events.js"))],
 ["smoke alpha assets preserved",["smoke-alpha-red.webp","smoke-alpha-cyan.webp","smoke-alpha-neutral.webp","smoke-alpha-warm.webp"].every(a=>fs.existsSync(path.join(root,"web/assets/brand-heroes",a)))],
];
let bad=0; for(const [name,ok] of checks){console.log(`${ok?"PASS":"FAIL"} · ${name}`); if(!ok) bad++;}
if(bad) process.exit(1);
console.log("OK KOMBAX 20.101 R15 Responsive Visual Tuning");
