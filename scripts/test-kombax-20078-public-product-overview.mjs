import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const config=read('web/config.js');
const index=read('web/index.html');
const worker=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');
const overview=read('web/js/public-product-overview.js');
const overviewCss=read('web/css/kombax-public-overview.css');

assert.equal(Number(config.match(/build:\s*(\d+)/)?.[1]),20078);
assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),20078);
assert.match(index,/manifest\.webmanifest\?v=20078/);
assert.match(index,/kombax-public-overview\.css\?v=20078/);
assert.match(index,/public-product-overview\.js\?v=20078/);
assert.match(worker,/rc13-20078/);
assert.match(index,/deportes de contacto y artes marciales/i);
assert.match(overview,/deportes de contacto y artes marciales/i);
assert.match(overview,/gateway-club/);
assert.match(overview,/gateway-direct/);
assert.match(overview,/featureIcon/);
assert.match(overviewCss,/\.kx-product-card\.is-featured/);
assert.match(overviewCss,/@media\(max-width:620px\)/);
assert.match(overviewCss,/prefers-reduced-motion/);

const labels=['CLUBES','FEDERACIONES','COMPETIDORES','MARCAS'];
let cursor=-1;
for(const label of labels){
  const next=overview.indexOf(`label: '${label}'`);
  assert.ok(next>cursor,`Orden público incorrecto para ${label}`);
  cursor=next;
}

for(const rel of ['index.html','config.js','service-worker.js','css/kombax-public-overview.css','js/public-product-overview.js']){
  const web=read(`web/${rel}`);
  assert.equal(read(`dist/${rel}`),web,`dist desincronizado: ${rel}`);
  assert.equal(read(`android/app/src/main/assets/www/${rel}`),web,`Android desincronizado: ${rel}`);
}

console.log('KOMBAX 20078 public product overview: PASS');
