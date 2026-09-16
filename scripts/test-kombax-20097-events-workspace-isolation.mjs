import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(`../${p}`,import.meta.url),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL 20097 EVENTS WORKSPACE: ${msg}`);console.log(`OK 20097: ${msg}`)};
const [config,sw,index,repo,events,m171,m172,m190,post,gradle,main,health]=await Promise.all([
 read('web/config.js'),read('web/service-worker.js'),read('web/index.html'),read('web/js/core/repositories.js'),read('web/js/modules/kombax-events.js'),
 read('supabase/migrations/171_kombax_events_workspace_isolation_20097.sql'),read('supabase/migrations/172_kombax_events_workspace_invitations_20097.sql'),read('supabase/migrations/190_kombax_events_bundle_roles_20101_r22.sql'),read('POSTDEPLOY_ENABLE_URBAN_WARRIORS_EVENTS_20097.sql'),
 read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/functions/health/index.ts')
]);
const b=Number(config.match(/build:\s*(\d+)/)?.[1]||0),a=Number(gradle.match(/versionCode\s+(\d+)/)?.[1]||0),w=Number(sw.match(/-(\d+)'/)?.[1]||0),h=Number(health.match(/build:(\d+)/)?.[1]||0);
assert(b>=20097&&a>=20097&&w>=20097&&h>=20097,'identidad 20097 o superior consistente en web/PWA/Android/health local');
assert(repo.includes("app_kombax_eventos_organizador_contexto_v171")&&repo.includes('p_club_id:session().club_id'),'organizador se resuelve por club activo');
assert(repo.includes("app_kombax_eventos_invitaciones_contexto_v172"),'invitaciones se resuelven por club activo');
const workspaceGatewayVersion=Math.max(0,...[...repo.matchAll(/app_kombax_eventos_mutate_v(\d+)/g)].map(m=>Number(m[1])));assert(workspaceGatewayVersion>=171&&repo.includes('workspace_club_id:session()?.club_id||null'),'mutaciones usan gateway 171+ y transportan workspace_club_id explícito');
assert((repo.includes('app_kombax_evento_contexto_gestion_v171')||(repo.includes('app_kombax_evento_bundle_v189')&&repo.includes('p_workspace_club_id:session()?.club_id||null')&&m190.includes('app_kombax_evento_contexto_gestion_v171'))),'detalle revalida permisos de gestión dentro del workspace, directa o mediante bundle actual');
assert(events.includes('contexto aislado:')&&events.includes('Mi Club > Eventos continúa siendo privado y separado.'),'editor y detalle mantienen señal contextual/separación explícita');
assert(m171.includes('EVENT_WORKSPACE_SUBJECT_MISMATCH')&&m171.includes('EVENT_WORKSPACE_DIRECT_PROFILE_FORBIDDEN'),'gateway bloquea cruces club ↔ perfil directo');
assert(m171.includes("sp.sujeto_tipo='club' and sp.club_id=c.id"),'RPC contextual devuelve solo el perfil Club del workspace');
const sql171=m171.replace(/--[^\n]*/g,'');
assert(!/public\.eventos_competicion\b|public\.evento_participantes\b|public\.evento_combates\b/.test(sql171),'migración contextual no consulta Eventos internos de Mi Club');
assert(m172.includes("sp.sujeto_tipo='club' and sp.club_id=p_club_id"),'invitaciones quedan filtradas al perfil público del club');
assert(post.includes("c.slug='urban-warriors'")&&post.includes("'events.public.organize'")&&post.includes("'promocion'"),'activación piloto Urban Warriors está preparada como post-deploy explícito');
assert(!m171.includes("c.slug='urban-warriors'")&&!m172.includes("c.slug='urban-warriors'"),'migraciones de aislamiento son genéricas y no hardcodean el piloto');
assert(/KOMBAXApp\/2\.0\.0-rc\.13\/20(?:097|09[8-9]|1\d{2,})/.test(main),'Android identifica build 20097 o superior');
console.log('PASS 20097 KOMBAX Events Workspace Isolation');
