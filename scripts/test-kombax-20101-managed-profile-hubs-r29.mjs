import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(fileURLToPath(new URL('..',import.meta.url)));const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const gateway=read('web/js/modules/gateway.js'),hub=read('web/js/modules/managed-profile-hub.js'),repos=read('web/js/core/repositories.js'),sql=read('supabase/migrations/199_kombax_managed_profile_hubs_20101_r29.sql'),css=read('web/css/kombax-premium.css'),index=read('web/index.html'),sw=read('web/service-worker.js');
const wrappers=['federation-hub.js','brand-hub.js','professional-hub.js','competitor-hub.js','spectator-hub.js'].every(f=>fs.existsSync(path.join(root,'web/js/modules',f)));
const checks=[
 ['Five distinct hubs',hub.includes("title:'Mi Federación'")&&hub.includes("title:'Mi Marca'")&&hub.includes("title:'Mi actividad'")&&hub.includes("title:'Mi Competidor'")&&hub.includes("title:'Mi perfil'")&&wrappers],
 ['Gateway opens managed hub',gateway.includes('data-kx-profile-open-hub')&&gateway.includes('renderManagedProfileHub')],
 ['Workspace repository v197',repos.includes('app_kombax_managed_profile_hub_v197')],
 ['Federation privacy boundary',hub.includes('La afiliación o relación con un club no concede acceso')&&sql.includes("'private_club_access',false")],
 ['Spectator remains non publisher',hub.includes('no publicadora por defecto')&&hub.includes('Espectador puede consumir y guardar contenido')],
 ['Backend authenticates and checks subject',sql.includes("auth.uid()")&&sql.includes("app_kombax_puede_gestionar_perfil_v070(p_perfil_directo_id,'read')")],
 ['Backend grants only authenticated',sql.includes('revoke all on function public.app_kombax_managed_profile_hub_v197(uuid) from public,anon')&&sql.includes('grant execute on function public.app_kombax_managed_profile_hub_v197(uuid) to authenticated')],
 ['Responsive managed hub',css.includes('.kx-managed-grid')&&css.includes('@media(max-width:520px)')],
 ['R29 cache bust',index.includes('20101r29')&&sw.includes('media-r29')]
];let ok=0;for(const [n,v] of checks){if(!v){console.error('FAIL · '+n);process.exitCode=1}else{ok++;console.log('PASS · '+n)}}console.log(`R29 ${ok}/${checks.length}`);
