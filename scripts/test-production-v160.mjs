import { readFile, access } from 'node:fs/promises';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=(p)=>readFile(resolve(root,p),'utf8');
const [config,netlify,index,store,app,migration,pkg]=await Promise.all([
 read('web/config.js'),read('netlify.toml'),read('web/index.html'),read('web/js/data-store.js'),read('web/js/app.js'),read('supabase/migrations/015_mutation_governance_v160.sql'),read('package.json').then(JSON.parse)
]);
const required=['web/index.html','web/config.js','web/js/data-store.js','web/js/app.js','web/service-worker.js','supabase/migrations/015_mutation_governance_v160.sql','android/app/build.gradle'];
for(const f of required) await access(resolve(root,f));
if(!config.includes('demoMode: false')) throw new Error('demoMode debe ser false');
if(!config.includes("enabled: true")) throw new Error('Supabase debe estar habilitado');
if(!/https:\/\/[a-z0-9-]+\.supabase\.co/.test(config)) throw new Error('URL Supabase inválida');
if(!config.includes('sb_publishable_')) throw new Error('Debe usarse publishable key, no service_role');
if(/service_role|SUPABASE_SERVICE_ROLE/i.test(config)) throw new Error('Secreto service_role expuesto en config');
if(!netlify.includes('command = "npm run build"') || !netlify.includes('publish = "dist"')) throw new Error('Netlify no ejecuta build gobernado');
if(!netlify.includes('no-cache, no-store, must-revalidate')) throw new Error('Falta no-store para config/service worker');
if(!index.includes('?v=1.6.0-b12')) throw new Error('Assets sin cache bust');
if(!store.includes('app_mutate_v160') || !migration.includes('app_mutate_v160')) throw new Error('Gateway ausente');
if(!app.includes('finishMutation')) throw new Error('UX post-guardado ausente');
if(pkg.scripts.build.includes('test-governance-v160')===false) throw new Error('El deploy no ejecuta preflight de gobernanza');
console.log(`OK: preflight de producción 1.6.0 (${required.length} archivos críticos).`);
