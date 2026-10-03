import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const configPath=resolve(root,'web/config.js');
const indexPath=resolve(root,'web/index.html');
const workerPath=resolve(root,'web/service-worker.js');

const config=await readFile(configPath,'utf8');
const buildMatch=config.match(/build:\s*(\d+)/);
const versionMatch=config.match(/version:\s*'([^']+)'/);
if(!buildMatch) throw new Error('KOMBAX_RELEASE_BUILD_NOT_FOUND');
if(!versionMatch) throw new Error('KOMBAX_RELEASE_VERSION_NOT_FOUND');
const build=buildMatch[1];
const releaseVersion=versionMatch[1];
const releaseSuffix=releaseVersion.replace(/^2\.0\.0-rc\.13-?/,'');

const indexBefore=await readFile(indexPath,'utf8');
const indexAfter=indexBefore.replace(/((?:href|src)="[^"]*?[?&]v=)\d+/g,(_,prefix)=>prefix+build);
if(!new RegExp('(?:href|src)="[^"]*?[?&]v='+build+'(?:[-"&]|$)').test(indexAfter)){
  throw new Error('KOMBAX_RELEASE_ASSET_VERSION_NOT_APPLIED:'+build);
}
if(indexAfter!==indexBefore) await writeFile(indexPath,indexAfter,'utf8');

const workerBefore=await readFile(workerPath,'utf8');
let workerAfter=workerBefore.replace(/const BUILD_MARKER='kombax-build-\d+';/,`const BUILD_MARKER='kombax-build-${build}';`);
workerAfter=workerAfter.replace(/const VERSION='kombax-2\.0\.0-rc13-\d+-[^']+';/,`const VERSION='kombax-2.0.0-rc13-${build}-${releaseSuffix}';`);
if(!workerAfter.includes(`kombax-build-${build}`)||!workerAfter.includes(`rc13-${build}`)){
  throw new Error('KOMBAX_RELEASE_SERVICE_WORKER_VERSION_NOT_APPLIED:'+build);
}
if(workerAfter!==workerBefore) await writeFile(workerPath,workerAfter,'utf8');

console.log('KOMBAX release assets and service worker synced to build '+build);
