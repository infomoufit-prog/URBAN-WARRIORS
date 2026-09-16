import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('web/js/modules/kombax-events.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const fighters=[
'fighter-adrian-cruz.webp','fighter-bruno-mota.webp','fighter-claudia-sanz.webp','fighter-dario-moreno.webp','fighter-hugo-salvatierra.webp','fighter-ivan-keller.webp','fighter-leo-serra.webp','fighter-maia-costa.webp','fighter-marcos-duran.webp','fighter-nerea-rivas.webp','fighter-vera-leon.webp','fighter-youssef-kadi.webp'];
const webOk=fighters.every(f=>fs.existsSync(path.join(root,'web/assets/demo-events/noche-impacto-barcelona',f)));
const androidOk=fighters.every(f=>fs.existsSync(path.join(root,'android/app/src/main/assets/www/assets/demo-events/noche-impacto-barcelona',f)));
const checks=[
 ['demo URL rewrite no longer depends on localhost',js.includes("if(/^https:\\/\\/(?:www\\.)?kombax\\.es\\/assets\\/demo-events\\//i.test(v))v=v.replace")&&!js.includes("demo-events\\//i.test(v)&&/^(localhost|127\\.0\\.0\\.1)" )],
 ['12 BCN fighter assets present in web',webOk],
 ['12 BCN fighter assets present in Android',androidOk],
 ['fight cards use resolvedFighterPhoto',js.includes('resolvedFighterPhoto(f.a_foto_url,f.a_nombre)')&&js.includes('resolvedFighterPhoto(f.b_foto_url,f.b_nombre)')],
 ['participant cards use fighterPhoto',js.includes('src="${esc(fighterPhoto(p))}"')],
 ['main event uses resolved fighter photos',js.includes('resolvedFighterPhoto(f?.a_foto_url,f?.a_nombre)')&&js.includes('resolvedFighterPhoto(f?.b_foto_url,f?.b_nombre)')],
 ['external non-demo https remains supported',js.includes("return /^(https?:\\/\\/|\\.\\/|\\/)/i.test(v)?v:''")],
 ['Urban explicit hardening preserved',js.includes("'Malik Benítez':'./assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic/malik-benitez.webp'")],
 ['cache bumped to R18',revisionAtLeast(index,18)&&revisionAtLeast(sw,18,'media-r')]
];
let bad=0; for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log('OK KOMBAX 20.101 R18 Demo Event Image Routing Hardening');
