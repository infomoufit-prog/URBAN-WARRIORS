import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd(), found=new Map();
function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,item.name);if(item.isDirectory())walk(p);else if(p.endsWith('.js')){const text=fs.readFileSync(p,'utf8');for(const m of text.matchAll(/['"](app_[a-z0-9_]+)['"]/g)){const files=found.get(m[1])||new Set();files.add(path.relative(root,p).replaceAll('\\','/'));found.set(m[1],files);}}}}
walk(path.join(root,'web/js'));
console.log(JSON.stringify([...found].map(([name,files])=>({name,files:[...files]}))));
