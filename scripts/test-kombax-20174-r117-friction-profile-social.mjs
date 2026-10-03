import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [config,gradle,mainActivity,app,gateway,members,utils,platformAdmin,backend,birthCore,birthModule,m308,m309,m310,m311,m312,m313,m314,baseline]=await Promise.all([
  read('web/config.js'),read('android/app/build.gradle'),read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),
  read('web/js/app.js'),read('web/js/modules/gateway.js'),read('web/js/modules/groups-members.js'),read('web/js/core/utils.js'),
  read('web/js/modules/platform-admin.js'),read('web/js/core/backend.js'),read('web/js/core/account-birth-date.js'),read('web/js/modules/account-birth-date.js'),
  read('supabase/migrations/308_kombax_registration_birth_date_contract_r117.sql'),
  read('supabase/migrations/309_kombax_member_save_optional_sport_r117.sql'),
  read('supabase/migrations/310_kombax_preenrollment_optional_sport_r117.sql'),
  read('supabase/migrations/311_kombax_progressive_club_enrollment_r117.sql'),
  read('supabase/migrations/312_kombax_pilot_club_minimal_progressive_r117.sql'),
  read('supabase/migrations/313_kombax_member_social_profile_canonical_age_r117.sql'),
  read('supabase/migrations/314_kombax_professional_social_profile_progressive_r117.sql'),
  read('BASELINE_R117_20174_FRICTION_PROFILE_SOCIAL.txt')
]);
const checks=[]; const ok=(name,condition)=>{assert.ok(condition,name);checks.push(name)};

ok('web build 20174',/build:\s*20174/.test(config));
ok('release hotfix 4',/r117-pilot-hotfix-4/.test(config));
ok('Android versionCode 20174',/versionCode\s+20174/.test(gradle));
ok('Android release name hotfix 4',/r117-pilot-hotfix-4/.test(gradle));
ok('Android UA 20174',/KOMBAXApp\/2\.0\.0-rc\.13\/20174/.test(mainActivity));

ok('global account signup sends canonical DOB',/registerGlobalAccount\(\{[^}]*fecha_nacimiento/.test(backend)&&/client\.signUp\(email,password,\{nombre,apellidos,fecha_nacimiento:birth\.value/.test(backend));
ok('club-member signup sends canonical DOB',/client\.signUp\(input\.email,input\.password,\{nombre:input\.adulto_nombre,apellidos:input\.adulto_apellidos,fecha_nacimiento:birth\.value/.test(backend));
ok('historic DOB completion RPC remains wired',/app_kombax_account_birth_date_set_r117/.test(backend));
ok('DOB helper keeps ISO validation',/\^\\d\{4\}-\\d\{2\}-\\d\{2\}\$/.test(birthCore));
ok('DOB completion is explicitly private',/No se muestra en tu perfil público/.test(birthModule));
ok('Auth trigger still requires raw signup DOB',/new\.raw_user_meta_data->>'fecha_nacimiento'/.test(m308));

ok('member UI discipline optional',/Disciplina · opcional/.test(members));
ok('member UI group optional',/Grupo · opcional/.test(members));
ok('member backend saves without discipline',/if v_disciplina_id is null then return v_id/.test(m309));
ok('member backend has no old discipline+group hard gate',!/Selecciona una disciplina y un grupo/.test(m309));
ok('pre-enrollment approval sport optional',/if v_disciplina_id is not null then/.test(m310));

ok('club registration UI discipline optional',/Disciplina · opcional/.test(app));
ok('club registration UI phone optional',/Teléfono',help:'Opcional/.test(app));
ok('club registration is a linking request',/solicitud de vinculación/.test(app));
ok('pre-enrollment has no prior membership prerequisite',!/es_miembro_club\(p_club_id\)/.test(m311));
ok('account registration does not create membership prematurely',!/insert into public\.miembros_club[\s\S]*v_preinscripcion_id:=public\.app_crear_preinscripcion/.test(m311.split('create or replace function public.app_kombax_preinscripcion_aprobar_r59')[0]));
ok('account registration explicitly reports pending membership',/membership_created',false/.test(m311));
ok('direct family approval exists',/family_linked/.test(m311));
ok('invitation remains an alternative',/app_kombax_alumno_invitar_r58/.test(m311));

ok('pilot UI location optional',/Ubicación pública · opcional/.test(gateway));
ok('pilot UI disciplines optional',/Disciplinas · opcional/.test(gateway));
ok('pilot UI phone optional',/Teléfono de contacto del Club · opcional/.test(gateway));
ok('pilot UI no discipline hard stop',!/Indica al menos una disciplina/.test(gateway));
ok('pilot backend location optional',!/KOMBAX_CLUB_LOCATION_REQUIRED/.test(m312));
ok('pilot backend disciplines optional',!/KOMBAX_CLUB_DISCIPLINES_REQUIRED/.test(m312));
ok('pilot backend phone optional',!/KOMBAX_CLUB_PHONE_REQUIRED/.test(m312));
ok('pilot backend no approval/code/document',/invite_code_required',false/.test(m312)&&/approval_required',false/.test(m312)&&/document_verification_required',false/.test(m312));

ok('member Perfil Social uses canonical private DOB',/app_kombax_account_birth_date_set_r117/.test(m313));
ok('member independent profile minimum age retained',/KOMBAX_MEMBER_INDEPENDENT_MIN_AGE_16/.test(m313));
ok('member without club feed disabled',/publication_enabled',false/.test(m313));
ok('member without club album enabled',/album_enabled',true/.test(m313));
ok('member without club network enabled',/network_enabled',true/.test(m313));

ok('professional social profile specialty optional in UI',/Especialidad principal · opcional/.test(gateway)&&/Completar más adelante/.test(gateway));
ok('professional profile backend accepts blank specialty',/if v_primary='''' then/.test(m314));
ok('professional supplied specialty still validated',/KOMBAX_PROFESSIONAL_SPECIALTY_INVALID/.test(m314));
ok('professional verification still requires specialty',/Especialidad profesional[\s\S]{0,160}required:true/.test(gateway));

ok('duplicate imported member gets human message',/KOMBAX_POSSIBLE_IMPORTED_MEMBER_REVIEW_REQUIRED/.test(utils));
ok('duplicate pending enrollment gets human message',/KOMBAX_DUPLICATE_PENDING_PRE_ENROLLMENT/.test(utils));
ok('pilot admin legacy copy says no code',/sin código de invitación, sin documentación inicial y sin revisión manual previa/.test(platformAdmin));
ok('canonical baseline terminology uses Perfil Social',/Perfil Social/.test(baseline));
ok('canonical baseline does not use Elite Social',!/Elite Social/.test(baseline));

console.log(`PASS ${checks.length}/${checks.length} · KOMBAX R117 build 20174 friction / Perfil Social / progressive registration`);
for(const name of checks)console.log(`  ✓ ${name}`);
