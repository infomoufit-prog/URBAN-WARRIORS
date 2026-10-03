import assert from 'node:assert/strict';
import {readFileSync,readdirSync,existsSync} from 'node:fs';
import {resolve,dirname,relative} from 'node:path';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';

const root=resolve(import.meta.dirname,'..'),web=resolve(root,'web');
const files=dir=>readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(resolve(dir,e.name)):[resolve(dir,e.name)]);
const sha=file=>createHash('sha256').update(readFileSync(file)).digest('hex');
const listings=new Map();
function exactFile(file){
  const rel=relative(web,file);
  assert.ok(rel&&!rel.startsWith('..'),'Import outside web: '+file);
  let current=web;
  for(const part of rel.split(/[\\/]/)){
    if(!listings.has(current))listings.set(current,readdirSync(current));
    assert.ok(listings.get(current).includes(part),'Missing file or Linux filename case mismatch: '+file);
    current=resolve(current,part);
  }
}
let scripts=0,imports=0;
const syntaxFiles=[];
for(const file of files(web)){
  const rel=relative(web,file);
  const original=sha(file);
  for(const copy of ['dist','android/app/src/main/assets/www'])assert.equal(sha(resolve(root,copy,rel)),original,'Generated copy drift: '+rel);
  if(!file.endsWith('.js'))continue;
  syntaxFiles.push(file);
  scripts++;
  const source=readFileSync(file,'utf8');
  const dependency=/(?:\b(?:import|export)\s+(?:[^;]*?\s+from\s*)?|\bimport\s*\(\s*)(['"])(\.{1,2}\/[^'"\n]+)\1/g;
  for(const match of source.matchAll(dependency)){
    exactFile(resolve(dirname(file),match[2].split(/[?#]/)[0]));imports++;
  }
}
// Parse every module with Node's ECMAScript module parser in one child.
// No module is linked or evaluated. Repeated process startup is slow on Windows.
const syntax=spawnSync(process.execPath,['--experimental-vm-modules','--no-warnings','scripts/check-web-module-syntax.mjs'],{
 cwd:root,input:JSON.stringify(syntaxFiles),encoding:'utf8',timeout:120000,maxBuffer:1024*1024,
});
assert.equal(syntax.status,0,syntax.stderr||syntax.error?.message||'Module syntax check failed');
assert.equal(Number(syntax.stdout.trim()),syntaxFiles.length,'Not every module was parsed');
const config=readFileSync(resolve(web,'config.js'),'utf8');
const build=Number(config.match(/build:\s*(\d+)/)?.[1]);
const version=config.match(/version:\s*'([^']+)'/)?.[1];
const pkg=JSON.parse(readFileSync(resolve(root,'package.json'),'utf8'));
const gradle=readFileSync(resolve(root,'android/app/build.gradle'),'utf8');
assert.equal(pkg.version,version);
assert.equal(Number(gradle.match(/versionCode\s+(\d+)/)?.[1]),build);
assert.ok(gradle.includes(`versionName '${version}'`));
const worker=readFileSync(resolve(web,'service-worker.js'),'utf8');
assert.equal(worker.match(/^const BUILD_MARKER='([^']+)';$/m)?.[1],`kombax-build-${build}`);
assert.equal(worker.match(/^const VERSION='([^']+)';$/m)?.[1],`kombax-2.0.0-rc13-${build}-${version.replace(/^2\.0\.0-rc\.13-?/,'')}`);
for(const page of ['index.html','privacy.html','terms.html','child-safety.html','delete-account.html'])assert.ok(existsSync(resolve(web,page)));
assert.ok(existsSync(resolve(root,'android/gradle/wrapper/gradle-wrapper.jar')));
JSON.parse(readFileSync(resolve(web,'manifest.webmanifest'),'utf8'));
console.log(`PASS compatibility · ${scripts} JavaScript files · ${imports} local imports checked for Linux · build ${build} · web/dist/Android identical`);
