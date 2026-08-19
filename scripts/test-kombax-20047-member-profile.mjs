import fs from 'node:fs';
const read=p=>fs.readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
const fail=m=>{console.error('FAIL 20047 MEMBER PROFILE:',m);process.exit(1)};
const ok=(c,m)=>{if(!c)fail(m)};

const mig=read('supabase/migrations/093_kombax_member_public_profile_null_badge_fix_20047.sql');
const profile=read('web/js/modules/public-profile.js');
const portal=read('web/js/modules/portal.js');
const admin=read('web/js/modules/admin.js');
const legal=read('web/js/modules/help-legal.js');
const gateway=read('web/js/modules/gateway.js');
const social=read('web/js/modules/kombax-social.js');
const css=read('web/css/kombax-premium.css');
const cfg=read('web/config.js');
const idx=read('web/index.html');
const sw=read('web/service-worker.js');
const gradle=read('android/app/build.gradle');

ok(mig.includes("coalesce(to_jsonb(v_badge),'null'::jsonb)"),'badge NULL no puede anular el perfil público');
ok(mig.includes('app_kombax_perfil_publico_v072'),'corrige el wrapper público que alimenta v083');
ok(mig.includes('grant execute on function public.app_kombax_perfil_publico_v072(uuid) to authenticated'),'perfil sigue disponible solo a autenticados');

ok(profile.includes('openMemberAlbum(')&&profile.includes('kx-public-member-album'),'Miembro tiene gestor de álbum propio');
ok(profile.includes("photos.length>=10")&&profile.includes("videos.length>=3"),'UI respeta 10 fotos / 3 vídeos');
ok(profile.includes("máximo 15 s por vídeo")||profile.includes("Máximo 15 segundos"),'UI comunica límite de 15 s');
ok(profile.includes("uploadMedia(profile.id,kind,v.archivo,{enAlbum:true,audience:'publica'})"),'subida de álbum Miembro se publica como contenido público');
ok(profile.includes('kx-public-member-album'),'perfil propio expone gestión de álbum');
ok(profile.includes('Perfil Miembro')&&profile.includes('La insignia KOMBAX')&&profile.includes('Competidor verificado'),'Miembro enriquecido sigue diferenciado de Competidor');

ok(legal.includes('export async function openPrivacyConditions()'),'existe centro legal dedicado');
const build=Number((cfg.match(/build:\s*(\d+)/)||[])[1]||0);
ok(build>=20047,'build debe conservar las garantías 20047');
if(build===20047)ok(portal.includes("id=\"portal-privacy-conditions\"")&&portal.includes('openPrivacyConditions'),'20.047 abre privacidad real desde perfil deportivo');
else ok(profile.includes('kx-public-legal')&&profile.includes('openPrivacyConditions'),'build posterior abre privacidad desde el perfil KOMBAX canónico');
ok(admin.includes("id=\"open-privacy-conditions\"")&&admin.includes('openPrivacyConditions'),'perfil personal abre privacidad real');
ok(!portal.includes('href="#help">Privacidad y condiciones'),'Privacidad y condiciones no deriva al manual');
ok(!admin.includes("'Privacidad y condiciones','Consulta condiciones, privacidad, Comunidad del Club y derechos de imagen','<a class=\"btn btn-ghost btn-sm\" href=\"#help\">Abrir</a>'"),'perfil personal ya no deriva privacidad al manual');

ok(social.includes('data-social-profile-open="${esc(p.autor_id)}"'),'feed conserva author social_id para abrir perfil');
ok(social.includes('data-social-profile-open="${esc(p.id)}"'),'directorio conserva social_id para abrir perfil');
ok(gateway.includes('ficha Social pública enriquecida')&&!gateway.includes('Miembro permanece como perfil Social básico'),'producto deja de describir Miembro como perfil básico');
ok(css.includes('20.047 · Member public profile enrichment'),'estilos premium específicos de ficha Miembro incluidos');

ok(build>=20047,'config mantiene build 20047 o posterior');
ok(Number((gradle.match(/versionCode\s+(\d+)/)||[])[1]||0)>=20047,'Android mantiene versionCode 20047 o posterior');
ok(idx.includes(`?v=${build}`),'assets web invalidan caché con build actual');
ok(sw.includes(`uw2-2.0.0-rc13-${build}`),'service worker usa cache del build actual');
console.log('KOMBAX BUILD 20047 · member enriched public profile + legal routing: PASS');
