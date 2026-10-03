import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const configPath=resolve(root,'web/config.js');
const indexPath=resolve(root,'web/index.html');

const config=await readFile(configPath,'utf8');
const match=config.match(/build:\s*(\d+)/);
if(!match) throw new Error('KOMBAX_RELEASE_BUILD_NOT_FOUND');
const build=match[1];

const before=await readFile(indexPath,'utf8');
const after=before.replace(/((?:href|src)="[^"]*?[?&]v=)\d+/g,(_,prefix)=>prefix+build);

if(!new RegExp('(?:href|src)="[^"]*?[?&]v='+build+'(?:[-"&]|$)').test(after)){
  throw new Error('KOMBAX_RELEASE_ASSET_VERSION_NOT_APPLIED:'+build);
}
if(after!==before) await writeFile(indexPath,after,'utf8');
console.log('KOMBAX release assets synced to build '+build);
