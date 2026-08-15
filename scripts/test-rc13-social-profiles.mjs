import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(resolve(root,p),'utf8');
const assert=(ok,msg)=>{if(!ok)throw new Error(`FAIL RC13 SOCIAL: ${msg}`);console.log(`OK RC13 SOCIAL: ${msg}`)};
const [sql,preflight,verify,rollback,repos,community,profile,portal]=await Promise.all([
  read('supabase/migrations/032_social_profiles_likes.sql'),
  read('supabase/verification/preflight_032_social.sql'),
  read('supabase/verification/verify_032_social.sql'),
  read('supabase/rollbacks/032_social_profiles_likes.sql'),
  read('web/js/core/repositories.js'),read('web/js/modules/community.js'),read('web/js/modules/sports-profile.js'),read('web/js/modules/portal.js')
]);

assert(sql.includes('create table if not exists public.perfiles_deportivos'),'perfil deportivo está separado del perfil administrativo');
assert(sql.includes('visible boolean not null default false')&&sql.includes('moderacion_oculta boolean not null default false'),'privacidad del alumno y bloqueo de moderación son estados independientes');
assert(sql.includes('app_puede_editar_perfil_deportivo_v032')&&sql.includes('tutores_socios'),'titular y tutor vinculado pueden editar');
assert(sql.includes('app_puede_ver_perfil_deportivo_v032')&&sql.includes('public.es_miembro_club(p_club_id)'),'visibilidad exige membresía del mismo club');
assert(sql.includes('app_puede_moderar_perfil_deportivo_v032(p_club_id)\n        and exists(select 1 from public.perfiles_deportivos pd where pd.club_id=p_club_id and pd.socio_id=p_socio_id)'),'moderación no crea pseudo-perfiles para socios sin perfil deportivo');
assert(sql.includes('revoke all on public.perfiles_deportivos from public,anon,authenticated')&&!sql.includes('grant select on public.perfiles_deportivos to authenticated'),'tabla de perfil no ofrece SELECT directo al cliente');
assert(sql.includes("bucket_id='sports-profile-media'")&&sql.includes('app_puede_ver_perfil_deportivo_v032'),'foto deportiva privada respeta visibilidad del perfil');
assert(sql.includes("values(v_club,v_socio,nullif(v_payload->>'foto_path',''),false"),'subir solo una foto no publica el perfil accidentalmente');
assert(sql.includes('pd.visible and not pd.moderacion_oculta'),'lectura pública exige consentimiento y ausencia de bloqueo de moderación');
assert(sql.includes('moderacion_oculta=not v_active')&&!sql.includes('visible=v_active,\n      moderado_por'),'moderación no puede sobrescribir la preferencia de privacidad del alumno');

const rpc=sql.match(/create or replace function public\.app_perfiles_deportivos_publicos_v032[\s\S]*?revoke all on function public\.app_perfiles_deportivos_publicos_v032/)?.[0]||'';
for(const forbidden of ['telefono','email','fecha_nacimiento','direccion','contacto_emergencia','iban','documento'])assert(!new RegExp(`\\b${forbidden}\\b`,'i').test(rpc),`RPC pública no expone ${forbidden}`);
assert(rpc.includes('disciplinas jsonb')&&rpc.includes("'grado',g.nombre"),'disciplina/grado oficiales se derivan del club');

assert(sql.includes('foreign key(autor_socio_id) references public.socios(id) on delete set null'),'borrar un socio puede desacoplar el autor sin intentar anular club_id');
assert(sql.includes('create table if not exists public.comunidad_likes'),'likes tienen tabla propia');
assert(sql.includes('primary key(club_id,publicacion_id,perfil_id)'),'un usuario solo puede dar un like por publicación');
const likePolicy=sql.match(/create policy comunidad_likes_propios_v032[\s\S]*?\);/)?.[0]||'';
assert(likePolicy.includes('perfil_id=auth.uid()'),'cada usuario solo puede leer su propia fila de like');
assert(sql.includes("'liked',exists(")&&sql.includes("'likes_count',p.likes_count"),'mutación devuelve solo estado propio y contador');

const communityRepo=repos.slice(repos.indexOf('community:{'),repos.indexOf('legal:{'));
assert(communityRepo.includes('perfil_id=eq.${enc(session().id)}'),'frontend consulta únicamente likes propios');
assert(!communityRepo.includes('select=perfil_id,nombre')&&!communityRepo.includes('likers'),'no existe API frontend para listar identidades de likes');
assert(community.includes('data-like-count')&&community.includes("repos.community.like"),'Comunidad muestra y permite alternar el contador de likes');
assert(community.includes('openPublicDirectory')&&community.includes('openSportsProfile'),'Comunidad enlaza a directorio/perfil deportivo');
assert(profile.includes('Solo se comparte información deportiva')&&profile.includes('No incluyas teléfono, email, dirección'),'editor advierte y limita el contenido compartido');
assert(profile.includes('Perfil privado')&&profile.includes('Perfil oculto por moderación'),'frontend distingue privacidad voluntaria de moderación');
assert(portal.includes('Perfil deportivo compartido')&&portal.includes('foto deportiva'),'portal integra perfil deportivo separado de la cuenta');
assert(preflight.includes('app_finance_receipts_audit_v031')&&preflight.includes('app_multiclub_audit_v030'),'032 no debe aplicarse antes de certificar Finanzas 031 y hardening multiclub 030');
assert(verify.includes('perfil_sin_select_directo')&&verify.includes('likes_descuadrados'),'verificación cubre privacidad y consistencia de contador');
assert(rollback.includes('app_puede_ver_perfil_deportivo_v032'),'rollback cierra las nuevas lecturas seguras sin destruir datos');
console.log('RC13 SOCIAL + SPORTS PROFILES: PASS');
