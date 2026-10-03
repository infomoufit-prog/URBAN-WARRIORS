import { readFile, writeFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const webDir=resolve(root,'web');
const configPath=resolve(webDir,'config.js');
const workerPath=resolve(webDir,'service-worker.js');
const healthPath=resolve(root,'supabase/functions/health/index.ts');

const config=await readFile(configPath,'utf8');
const buildMatch=config.match(/build:\s*(\d+)/);
const versionMatch=config.match(/version:\s*'([^']+)'/);
if(!buildMatch) throw new Error('KOMBAX_RELEASE_BUILD_NOT_FOUND');
if(!versionMatch) throw new Error('KOMBAX_RELEASE_VERSION_NOT_FOUND');
const build=buildMatch[1];
const releaseVersion=versionMatch[1];
const releaseSuffix=releaseVersion.replace(/^2\.0\.0-rc\.13-?/,'');

for(const name of await readdir(webDir)){
  if(!name.endsWith('.html')) continue;
  const file=resolve(webDir,name);
  const before=await readFile(file,'utf8');
  const after=before.replace(/((?:href|src)="[^"]*?[?&]v=)\d+/g,(_,prefix)=>prefix+build);
  if(after!==before) await writeFile(file,after,'utf8');
}

const workerBefore=await readFile(workerPath,'utf8');
let workerAfter=workerBefore.replace(/const BUILD_MARKER='kombax-build-\d+';/,`const BUILD_MARKER='kombax-build-${build}';`);
workerAfter=workerAfter.replace(/const VERSION='kombax-2\.0\.0-rc13-\d+-[^']+';/,`const VERSION='kombax-2.0.0-rc13-${build}-${releaseSuffix}';`);
if(!workerAfter.includes(`kombax-build-${build}`)||!workerAfter.includes(`rc13-${build}`)){
  throw new Error('KOMBAX_RELEASE_SERVICE_WORKER_VERSION_NOT_APPLIED:'+build);
}
if(workerAfter!==workerBefore) await writeFile(workerPath,workerAfter,'utf8');

const healthBefore=await readFile(healthPath,'utf8');
let healthAfter=healthBefore.replace(/build:\d+/g,'build:'+build);
healthAfter=healthAfter.replace(/'x-kombax-build':'\d+'/g,"'x-kombax-build':'"+build+"'");
if(!healthAfter.includes('build:'+build)||!healthAfter.includes("'x-kombax-build':'"+build+"'")){
  throw new Error('KOMBAX_RELEASE_HEALTH_BUILD_NOT_APPLIED:'+build);
}
if(healthAfter!==healthBefore) await writeFile(healthPath,healthAfter,'utf8');

console.log('KOMBAX public HTML, service worker and health endpoint synced to build '+build);
