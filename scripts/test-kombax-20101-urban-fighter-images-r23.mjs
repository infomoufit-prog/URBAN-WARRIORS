import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const js=read('web/js/modules/kombax-events.js');
const serve=read('scripts/serve.mjs');
const index=read('web/index.html');
const sw=read('web/service-worker.js');
const fighters=['malik-benitez','bruno-sato','aina-torres','hana-ribeiro','daniel-ortiz','marc-vidal','laia-costa','emma-leon','leo-martin','hugo-rios'];
const names=['Malik Benítez','Bruno Sato','Aina Torres','Hana Ribeiro','Daniel Ortiz','Marc Vidal','Laia Costa','Emma León','Leo Martín','Hugo Ríos'];
const webDir=path.join(root,'web/assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic');
const androidDir=path.join(root,'android/app/src/main/assets/www/assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic');
const distDir=path.join(root,'dist/assets/demo-events/urban-warriors-jiujitsu-interclub/fighters-realistic');
const files=fighters.map(x=>`${x}.webp`);
const checks=[
 ['10 Urban fighter names remain mapped',names.every(n=>js.includes(`'${n}'`))],
 ['resolver prefers packaged demo portrait before backend URL',js.includes('if(local)return local;')&&js.indexOf('if(local)return local;')<js.indexOf('return safeImage(value)||fighterFallback;')],
 ['127.0.0.1 and Android appassets are recognised by runtime helper',js.includes('127\\.0\\.0\\.1')&&js.includes('appassets\\.androidplatform\\.net')],
 ['local CMD server serves WEBP with image/webp MIME',serve.includes("'.webp':'image/webp'")],
 ['local CMD server serves SVG fallback with image/svg+xml MIME',serve.includes("'.svg':'image/svg+xml; charset=utf-8'")],
 ['all 10 Urban portraits exist in web',files.every(f=>fs.existsSync(path.join(webDir,f)))],
 ['all 10 Urban portraits exist in dist',files.every(f=>fs.existsSync(path.join(distDir,f)))],
 ['all 10 Urban portraits exist in Android assets',files.every(f=>fs.existsSync(path.join(androidDir,f)))],
 ['web and Android portrait binaries are identical',files.every(f=>fs.readFileSync(path.join(webDir,f)).equals(fs.readFileSync(path.join(androidDir,f))))],
 ['web and dist portrait binaries are identical',files.every(f=>fs.readFileSync(path.join(webDir,f)).equals(fs.readFileSync(path.join(distDir,f))))],
 ['Fight Card uses hardened resolver',js.includes('resolvedFighterPhoto(f.a_foto_url,f.a_nombre)')&&js.includes('resolvedFighterPhoto(f.b_foto_url,f.b_nombre)')],
 ['Main Event uses hardened resolver',js.includes('resolvedFighterPhoto(f?.a_foto_url,f?.a_nombre)')&&js.includes('resolvedFighterPhoto(f?.b_foto_url,f?.b_nombre)')],
 ['participant cards use hardened resolver',js.includes('const fighterPhoto=p=>resolvedFighterPhoto(p?.foto_url,p?.nombre_publico);')],
 ['broken-image placeholder fallback remains',js.includes("img.addEventListener('error',fallback,{once:true})")],
 ['R23-or-later browser cache bust is active',(()=>{const a=Number(index.match(/20101r(\d+)/)?.[1]||0),b=Number(sw.match(/media-r(\d+)/)?.[1]||0);return a>=23&&b>=23;})()]
];
let bad=0;for(const [name,ok] of checks){console.log(`${ok?'PASS':'FAIL'} · ${name}`);if(!ok)bad++;}
if(bad)process.exit(1);
console.log(`R23 ${checks.length}/${checks.length}`);
