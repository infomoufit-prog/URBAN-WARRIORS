import assert from 'node:assert/strict';
import {readFileSync,existsSync,statSync} from 'node:fs';
import {resolve} from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=path=>readFileSync(resolve(root,path),'utf8');
const json=path=>JSON.parse(read(path));
const pass=message=>console.log('PASS',message);
const pdf=path=>{
  const file=resolve(root,'web',path.replace(/^\.\//,''));
  assert.ok(existsSync(file),'missing '+path);
  assert.ok(statSync(file).size>10000,'small '+path);
  assert.equal(readFileSync(file).subarray(0,4).toString(),'%PDF');
};
const config=read('web/config.js'),gradle=read('android/app/build.gradle');
assert.ok(Number(config.match(/2\.0\.0-rc\.13-r(\d+)-[a-z0-9-]+/)?.[1]||0)>=92);
assert.ok(Number(config.match(/build:\s*(\d+)/)?.[1]||0)>=20145);
assert.ok(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0)>=20145);
pass('R92 resources retained in cumulative web and Android build');

const catalog=json('web/assets/guides/resource-collections.json');
assert.equal(catalog.brand,'KOMBAX');
assert.equal(catalog.collections.length,3);
assert.equal(catalog.territories.length,19);
const sourceIds=catalog.collections.flatMap(x=>x.source_topics);
assert.equal(sourceIds.length,18);
assert.equal(new Set(sourceIds).size,18);
for(const group of catalog.collections){assert.ok(group.chapters.length>=5);pdf(group.pdf);}
for(const territory of catalog.territories)pdf(territory.pdf);
const runtime=json('web/assets/guides/runtime-index.json');
assert.equal(runtime.version,'20145-r92-resource-center');
assert.equal(runtime.entries.filter(x=>x.active!==false&&x.kind==='public').length,3);
assert.equal(runtime.entries.filter(x=>x.active!==false&&x.kind==='territorial').length,19);
assert.equal(runtime.entries.filter(x=>x.id.startsWith('r1001-')&&x.kind==='public'&&x.active!==false).length,0);
pass('Three rebuilt knowledge guides cover every original topic and 19 territories');

const usage=json('web/assets/guides/usage-guides.json');
const source=json('artifacts/guides-r100-1/usage-guides-source.json');
assert.equal(usage.guides.length,9);
assert.deepEqual(usage.guides.map(x=>x.id),source.guides.map(x=>x.id));
assert.deepEqual(new Set(usage.guides.map(x=>x.id)),new Set(['club','federacion','marca','competidor','profesional','espectador','alumno','familia','media']));
for(const guide of usage.guides){
  assert.ok(guide.chapters.length>=4);
  for(const chapter of guide.chapters)assert.ok(chapter.steps.length>=3);
  pdf(guide.pdf);
}
pass('Nine profile guides have readable web content and PDFs from one source');

const components=read('web/js/ui/components.js'),app=read('web/js/app.js'),center=read('web/js/modules/resource-center.js'),consulting=read('web/js/modules/consulting.js'),css=read('web/css/kombax-resource-center.css');
assert.match(components,/prepilot\.resources/);
for(const section of ['usage','knowledge','territories','consulting'])assert.match(components,new RegExp('data-resource-target="'+section+'"'));
assert.match(app,/resources:.*renderResourceCenter/);
assert.match(app,/id==='guides'\|\|id==='consulting'/);
assert.match(center,/sections\.forEach\(other=>\{if\(other!==el\)other\.open=false/);
assert.match(center,/renderConsulting\(\{container:/);
assert.match(consulting,/container\?container\.innerHTML/);
assert.match(css,/\.nav-primary\[data-nav="social"\]>span/);
assert.match(css,/box-shadow:inset/);
assert.match(css,/:focus-visible/);
pass('Single accordion resource center, embedded Consulting and Social LED icon');

assert.match(read('web/js/modules/managed-profile-hub.js'),/kx-managed-resources/);
assert.match(read('web/js/modules/gateway.js'),/kx-open-resources/);
assert.equal(existsSync(resolve(root,'web/assets/manuals/KOMBAX_MANUAL_GESTION_DE_CLUBES_R100_1.pdf')),false);
pass('Direct profile access and private manual boundary');
console.log('R92 RESOURCE CENTER GATE: PASS');
