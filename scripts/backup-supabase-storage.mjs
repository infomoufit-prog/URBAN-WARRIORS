#!/usr/bin/env node
import {mkdir, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join, dirname} from 'node:path';

const args=process.argv.slice(2);
const getArg=(name)=>{const i=args.indexOf(name);return i>=0?args[i+1]:null};
if(args.includes('--help')){
  console.log('Uso: node scripts/backup-supabase-storage.mjs --output <directorio> [--all]');
  console.log('Env: KOMBAX_SUPABASE_URL y KOMBAX_SERVICE_ROLE_KEY. Por defecto exporta solo buckets privados.');
  process.exit(0);
}
const output=getArg('--output');
if(!output)throw new Error('Falta --output <directorio>');
const base=(process.env.KOMBAX_SUPABASE_URL||'').replace(/\/+$/,'');
const key=process.env.KOMBAX_SERVICE_ROLE_KEY||'';
if(!base||!key)throw new Error('Define KOMBAX_SUPABASE_URL y KOMBAX_SERVICE_ROLE_KEY solo en esta sesión segura.');
const includeAll=args.includes('--all');
const headers={apikey:key,authorization:`Bearer ${key}`,'content-type':'application/json'};
async function api(path,opts={}){const r=await fetch(`${base}${path}`,{...opts,headers:{...headers,...opts.headers}});if(!r.ok)throw new Error(`${opts.method||'GET'} ${path}: ${r.status} ${await r.text()}`);return r;}
const stamp=new Date().toISOString().replace(/[-:]/g,'').replace(/\.\d{3}Z$/,'Z');
const root=join(output,`storage-${stamp}`);await mkdir(root,{recursive:true});
const buckets=await (await api('/storage/v1/bucket')).json();
const selected=buckets.filter(b=>includeAll||b.public===false);
const manifest={created_at:new Date().toISOString(),source:base,buckets:[],objects:[],sha256_algorithm:'SHA-256'};
for(const b of selected){
  manifest.buckets.push({id:b.id,name:b.name,public:Boolean(b.public),file_size_limit:b.file_size_limit??null,allowed_mime_types:b.allowed_mime_types??null});
  const stack=[''];
  while(stack.length){
    const prefix=stack.pop();let offset=0;
    for(;;){
      const body={prefix,limit:100,offset,sortBy:{column:'name',order:'asc'}};
      const rows=await (await api(`/storage/v1/object/list/${encodeURIComponent(b.id)}`,{method:'POST',body:JSON.stringify(body)})).json();
      if(!rows.length)break;
      for(const row of rows){
        const path=prefix?`${prefix}/${row.name}`:row.name;
        if(row.id==null){stack.push(path);continue;}
        const r=await api(`/storage/v1/object/${encodeURIComponent(b.id)}/${path.split('/').map(encodeURIComponent).join('/')}`);
        const bytes=new Uint8Array(await r.arrayBuffer());
        const dest=join(root,'objects',b.id,...path.split('/'));await mkdir(dirname(dest),{recursive:true});await writeFile(dest,bytes);
        const sha=createHash('sha256').update(bytes).digest('hex');
        manifest.objects.push({bucket:b.id,path,size:bytes.byteLength,sha256:sha,updated_at:row.updated_at??null,metadata:row.metadata??null});
      }
      if(rows.length<100)break;offset+=rows.length;
    }
  }
}
manifest.summary={bucket_count:manifest.buckets.length,object_count:manifest.objects.length,total_bytes:manifest.objects.reduce((n,o)=>n+o.size,0)};
const manifestBytes=Buffer.from(JSON.stringify(manifest,null,2)+'\n');
await writeFile(join(root,'manifest.json'),manifestBytes);
await writeFile(join(root,'manifest.sha256'),`${createHash('sha256').update(manifestBytes).digest('hex')}  manifest.json\n`);
console.log(JSON.stringify({ok:true,root,...manifest.summary},null,2));
