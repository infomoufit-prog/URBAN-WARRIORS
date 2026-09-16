import fs from 'node:fs';
import path from 'node:path';
const revisionAtLeast=(text,min,prefix='20101r')=>[...text.matchAll(new RegExp(`${prefix}(\\d+)`,'g'))].some(([,n])=>Number(n)>=min);
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('web/js/modules/kombax-events.js');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const names=['Malik Benítez','Bruno Sato','Aina Torres','Hana Ribeiro','Daniel Ortiz','Marc Vidal','Laia Costa','Emma León','Leo Martín','Hugo Ríos','Nico Serra','Ian Cruz'];
const assets=['action-adults-01.webp','action-adults-02.webp','action-adults-03.webp','action-adults-04.webp','action-adults-05.webp','action-adults-06.webp','action-adults-07.webp','action-adults-08.webp','youth-division.webp','registrations.webp','album-official.webp','results-highlights.webp'];
const checks=[
 ['12 demo fighters have deterministic local mapping',names.every(n=>js.includes(`'${n}'`))],
 ['all mapped assets exist in web',assets.every(a=>fs.existsSync(path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub',a)))],
 ['all mapped assets exist in Android package',assets.every(a=>fs.existsSync(path.join(root,'android/app/src/main/assets/www/assets/demo-events/urban-warriors-jiujitsu-interclub',a)))],
 ['packaged demo portraits keep priority over remote demo URLs',js.includes('if(local)return local;')],
 ['Fight Cards use hardened resolver',js.includes('resolvedFighterPhoto(f.a_foto_url,f.a_nombre)')&&js.includes('resolvedFighterPhoto(f.b_foto_url,f.b_nombre)')],
 ['participant images use fallback binding',js.includes('kx-fighter-chip-photo"><img data-kx-fighter-image')],
 ['Main Event images use fallback binding',js.includes('kx-main-fighter-photo"><img data-kx-fighter-image')],
 ['generic broken-image fallback remains',js.includes("img.addEventListener('error',fallback,{once:true})")],
 ['fallback asset exists in Android',fs.existsSync(path.join(root,'android/app/src/main/assets/www/assets/events/templates/fighter-placeholder.svg'))],
 ['cache is R17',revisionAtLeast(index,17)&&revisionAtLeast(sw,17,'media-r')]
];
let bad=0; for(const [n,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${n}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log('OK KOMBAX 20.101 R17 Android Fighter Image Hardening');
