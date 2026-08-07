import { cp, mkdir, rm, readFile, readdir } from 'node:fs/promises';
import { resolve, relative } from 'node:path';
import { createHash } from 'node:crypto';

const root = resolve(import.meta.dirname, '..');
const web = resolve(root, 'web');
const dist = resolve(root, 'dist');
const androidAssets = resolve(root, 'android/app/src/main/assets/www');

async function files(dir, base=dir) {
  const out=[];
  for (const entry of await readdir(dir,{withFileTypes:true})) {
    const full=resolve(dir,entry.name);
    if(entry.isDirectory()) out.push(...await files(full,base));
    else out.push(relative(base,full).replaceAll('\\','/'));
  }
  return out.sort();
}
async function digest(path) { return createHash('sha256').update(await readFile(path)).digest('hex'); }

for (const target of [dist, androidAssets]) {
  await rm(target, { recursive: true, force: true });
  await mkdir(target, { recursive: true });
  await cp(web, target, { recursive: true });
}
const sourceFiles=await files(web);
if(sourceFiles.some(f=>/\.bak$|\.old$|backup/i.test(f))) throw new Error('Build bloqueado: hay archivos de runtime obsoletos/backup');
for (const rel of sourceFiles) {
  const a=await digest(resolve(web,rel));
  const b=await digest(resolve(dist,rel));
  const c=await digest(resolve(androidAssets,rel));
  if(a!==b || a!==c) throw new Error(`Build no determinista: ${rel}`);
}
const storeText=await readFile(resolve(dist,'js/data-store.js'),'utf8');
if(!storeText.includes("const MUTATION_ENDPOINT = 'app_mutate_v160'")) throw new Error('Dist no contiene gateway 1.6.0');
if(/supabase\.rpc\(\s*['"]app_guardar/.test(storeText)) throw new Error('Dist contiene RPC históricas de escritura');
console.log(`Build web: ${dist}`);
console.log(`Assets Android: ${androidAssets}`);
console.log(`OK: ${sourceFiles.length} archivos idénticos web ↔ dist ↔ Android.`);
