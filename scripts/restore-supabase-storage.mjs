#!/usr/bin/env node
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
const args=process.argv.slice(2);const getArg=(name)=>{const i=args.indexOf(name);return i>=0?args[i+1]:null};
if(args.includes('--help')){console.log('Uso: node scripts/restore-supabase-storage.mjs --backup <storage-...> --target-url <url> --confirm-isolated TARGET_IS_ISOLATED');console.log('Env: KOMBAX_RESTORE_SERVICE_ROLE_KEY del proyecto AISLADO.');process.exit(0)}
const root=getArg('--backup'),target=(getArg('--target-url')||'').replace(/\/+$/,''),confirmation=getArg('--confirm-isolated');
const key=process.env.KOMBAX_RESTORE_SERVICE_ROLE_KEY||'';
if(!root||!target||!key)throw new Error('Faltan --backup, --target-url o KOMBAX_RESTORE_SERVICE_ROLE_KEY');
if(confirmation!=='TARGET_IS_ISOLATED')throw new Error('Restauración bloqueada: confirma explícitamente --confirm-isolated TARGET_IS_ISOLATED. Nunca ejecutar sobre LIVE.');
const headers={apikey:key,authorization:`Bearer ${key}`};
async function req(path,opts={}){const r=await fetch(`${target}${path}`,{...opts,headers:{...headers,...opts.headers}});if(!r.ok)throw new Error(`${opts.method||'GET'} ${path}: ${r.status} ${await r.text()}`);return r;}
const raw=await readFile(join(root,'manifest.json'));const manifest=JSON.parse(raw);let restored=0;
for(const bucket of manifest.buckets){
  const exists=await fetch(`${target}/storage/v1/bucket/${encodeURIComponent(bucket.id)}`,{headers}).then(r=>r.ok);
  if(!exists)await req('/storage/v1/bucket',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({id:bucket.id,name:bucket.name,public:false,file_size_limit:bucket.file_size_limit,allowed_mime_types:bucket.allowed_mime_types})});
}
for(const o of manifest.objects){
  const bytes=await readFile(join(root,'objects',o.bucket,...o.path.split('/')));const sha=createHash('sha256').update(bytes).digest('hex');if(sha!==o.sha256)throw new Error(`Hash inválido: ${o.bucket}/${o.path}`);
  await req(`/storage/v1/object/${encodeURIComponent(o.bucket)}/${o.path.split('/').map(encodeURIComponent).join('/')}`,{method:'POST',headers:{'content-type':'application/octet-stream','x-upsert':'true'},body:bytes});restored++;
}
console.log(JSON.stringify({ok:true,restored,target},null,2));
