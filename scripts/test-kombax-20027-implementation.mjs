import {readFile,access,readdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const exists=async p=>{try{await access(resolve(root,p));return true}catch{return false}};
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL KOMBAX 20027: ${msg}`);console.log(`OK KOMBAX 20027: ${msg}`)};
const [cfg,gradle,index,sw,gateway,repos,social,showcase,club,help,css,netlify,deletePage,deleteJs]=await Promise.all([
 read('web/config.js'),read('android/app/build.gradle'),read('web/index.html'),read('web/service-worker.js'),read('web/js/modules/gateway.js'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-social.js'),read('web/js/modules/showcase.js'),read('web/js/modules/club-profile.js'),read('web/js/modules/help-legal.js'),read('web/css/kombax-premium.css'),read('netlify.toml'),read('web/delete-account.html'),read('web/js/delete-account.js')
]);
const cfgBuild=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0),androidBuild=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0);
assert(cfgBuild>=20027&&androidBuild>=20027,'web y Android conservan o superan build 20027');
assert(gradle.includes("applicationId 'com.urbanwarriors.app'"),'applicationId histórico se conserva');
assert(index.includes(`kombax-premium.css?v=${cfgBuild}`)&&sw.includes(String(cfgBuild)),'assets y service worker invalidan caché con el build actual');
assert(gateway.includes('+ Solicitar perfil')&&gateway.includes("saveAndSubmitApplication('club'")&&gateway.includes('Privacidad y eliminación'),'hub global incluye selector oficial con alta Club y eliminación');
assert(gateway.includes('kx-open-social')&&gateway.includes('kx-open-showcase')&&gateway.includes('renderKombaxSocial')&&gateway.includes('renderShowcase'),'hub global abre Social y Showcase sin entrar artificialmente en un Club');
assert(social.includes('activateDirect')&&social.includes("socialStatus?.scope==='global'"),'activación Social global es voluntaria y separada por perfil directo');
assert(gateway.includes('Espectador continúa cerrado')||gateway.includes('Espectador sigue desactivado'),'Espectador continúa deshabilitado');
assert(repos.includes('app_kombax_perfil_mutate_v043')&&(repos.includes('app_kombax_social_mutate_v067')||repos.includes('app_kombax_social_mutate_v050')||repos.includes('app_kombax_social_mutate_v053')||repos.includes('app_kombax_social_mutate_v065'))&&repos.includes('app_kombax_relacion_mutate_v045'),'repositorios conservan perfiles/relaciones y una mutación Social compatible o superior a 050');
assert(club.includes('10 fotos')&&club.includes('3 vídeos')&&club.includes('máximo 15 s'),'Club dispone de álbum 10/3/15s');
assert(social.includes('Guardar')&&social.includes('Comentarios')&&(social.includes('Añadir a mi red')||social.includes('Vincular')),'Social expone guardados, comentarios y relaciones');
assert(social.includes("openReport('comentario'")&&social.includes('data-kx-comment-report'),'comentarios admiten denuncia desde la interfaz');
assert(social.includes('moderationQueue')&&social.includes('data-kx-moderate')&&repos.includes('app_kombax_moderation_queue_v050'),'moderadores disponen de cola y acciones auditadas 050');
assert(showcase.includes("máximo 15")&&showcase.includes("máximo 30")&&showcase.includes('galeria_3')&&showcase.includes('slice(0,3)'),'Showcase comunica límites Club/Marca y galería');
assert((repos.includes('app_kombax_showcase_mutate_v067')||repos.includes('app_kombax_showcase_mutate_v048')||repos.includes('app_kombax_showcase_mutate_v054'))&&repos.includes('app_kombax_showcase_mis_espacios_v048'),'Showcase global conserva mutación segura desacoplada y espacios 048');
assert(help.includes('Gestionar eliminación de cuenta')&&netlify.includes('/delete-account'),'eliminación existe en app y recurso web público');
assert(await exists('web/delete-account.html'),'recurso web delete-account existe');
assert(deletePage.includes('kx-delete-web-status')&&deletePage.includes('js/delete-account.js'),'recurso web carga flujo autenticado de eliminación');
assert(deleteJs.includes('backend.signInGlobal')&&deleteJs.includes("alcance:'account'")&&deleteJs.includes('repos.accountDeletion.request')&&deleteJs.includes('repos.accountDeletion.cancel'),'recurso web registra y cancela solicitudes reales');
for(const n of [43,44,45,46,47,48,49,50]){
 const prefix=String(n).padStart(3,'0')+'_';const migrations=await readdir(resolve(root,'supabase/migrations'));const rollbacks=await readdir(resolve(root,'supabase/rollbacks'));const verifications=await readdir(resolve(root,'supabase/verification'));
 assert(migrations.some(f=>f.startsWith(prefix)),`migración ${n} presente`);
 assert(rollbacks.some(f=>f.startsWith(prefix)),`rollback ${n} presente`);
 const nn=String(n).padStart(3,'0');assert(verifications.some(f=>f.startsWith(`preflight_${nn}_`)),`preflight ${n} presente`);
 assert(verifications.some(f=>f.startsWith(`verify_${nn}_`)),`verify ${n} presente`);
 assert(verifications.some(f=>f.startsWith(`test_${nn}_`)),`test transaccional ${n} presente`);
}
const sqls=await Promise.all((await readdir(resolve(root,'supabase/migrations'))).filter(f=>/^(043|044|045|046|047|048|049|050)_/.test(f)).sort().map(f=>read('supabase/migrations/'+f)));
for(const [i,sql] of sqls.entries()){
 assert(/^\s*(?:--[^\n]*\n\s*)*begin;/i.test(sql),`SQL nuevo ${i+43} abre transacción`);
 assert(/notify pgrst,'reload schema';\s*commit;/i.test(sql),`SQL nuevo ${i+43} cierra con reload + commit`);
 assert((sql.match(/\$\$/g)||[]).length%2===0,`SQL nuevo ${i+43} mantiene $$ equilibrados`);
}
const socialGlobal=await read('supabase/migrations/049_kombax_social_global_access.sql');
assert(socialGlobal.includes('KOMBAX_SOCIAL_CLUB_VERIFIED_AGE_REQUIRED')&&socialGlobal.includes("d.tipo in ('competidor','profesional')")&&socialGlobal.includes("'age_gate','club_verified_required'"),'Social directo de perfiles personales exige edad verificada por club');
for(const token of ['kx-profile-owned-grid','kx-album-grid','kx-deletion-center','kx-delete-web-grid','kx-moderation-list','kombax-post-media','showcase-detail-gallery'])assert(css.includes(token),`estilos incluyen ${token}`);
for(const p of ['.env','keystore.properties','google-services.json'])assert(!(await exists(p)),`${p} no se incrusta en raíz`);
console.log('KOMBAX BUILD 20027 IMPLEMENTATION STATIC: PASS');
