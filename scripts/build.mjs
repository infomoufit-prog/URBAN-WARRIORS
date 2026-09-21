import { cp, mkdir, rm, readFile, readdir } from 'node:fs/promises';
import { resolve, relative } from 'node:path';
import { createHash } from 'node:crypto';
const root=resolve(import.meta.dirname,'..'),web=resolve(root,'web'),dist=resolve(root,'dist'),android=resolve(root,'android/app/src/main/assets/www');
async function files(dir,base=dir){const out=[];for(const e of await readdir(dir,{withFileTypes:true})){const f=resolve(dir,e.name);if(e.isDirectory())out.push(...await files(f,base));else out.push(relative(base,f).replaceAll('\\','/'));}return out.sort();}
async function hash(p){return createHash('sha256').update(await readFile(p)).digest('hex')}
for(const target of [dist,android]){await rm(target,{recursive:true,force:true});await mkdir(target,{recursive:true});await cp(web,target,{recursive:true});}
const list=await files(web);for(const rel of list){const [a,b,c]=await Promise.all([hash(resolve(web,rel)),hash(resolve(dist,rel)),hash(resolve(android,rel))]);if(a!==b||a!==c)throw new Error(`Build no determinista: ${rel}`)}
const app=await readFile(resolve(web,'js/app.js'),'utf8'),backend=await readFile(resolve(web,'js/core/backend.js'),'utf8');
if(app.includes('data-store.js'))throw new Error('El frontend 2.0 no puede depender del store 1.x');
if(!backend.includes("cfg.release.mutationEndpoint"))throw new Error('Falta la puerta de mutación central');
console.log(`OK build ${list.length} archivos · web = dist = Android`);
