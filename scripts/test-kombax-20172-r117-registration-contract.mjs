import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

const root=resolve(import.meta.dirname,'..');
const read=rel=>readFile(resolve(root,rel),'utf8');
const [backend,app,gateway,utils,birthCore,birthModule,config,gradle,mainActivity,m307,m308]=await Promise.all([
  read('web/js/core/backend.js'),read('web/js/app.js'),read('web/js/modules/gateway.js'),read('web/js/core/utils.js'),
  read('web/js/core/account-birth-date.js'),read('web/js/modules/account-birth-date.js'),read('web/config.js'),read('android/app/build.gradle'),
  read('android/app/src/main/java/com/urbanwarriors/app/MainActivity.java'),read('supabase/migrations/307_kombax_pilot_club_direct_self_service_r117.sql'),read('supabase/migrations/308_kombax_registration_birth_date_contract_r117.sql')
]);

const checks=[];
const ok=(name,condition)=>{assert.ok(condition,name);checks.push(name);};

ok('build web 20172',/build:\s*20172/.test(config));
ok('release hotfix 2',/r117-pilot-hotfix-2/.test(config));
ok('Android versionCode 20172',/versionCode\s+20172/.test(gradle));
ok('Android UA 20172',/KOMBAXApp\/2\.0\.0-rc\.13\/20172/.test(mainActivity));

ok('registerGlobalAccount requires fecha_nacimiento',/registerGlobalAccount\(\{[^}]*fecha_nacimiento/.test(backend));
ok('global Auth signup sends fecha_nacimiento',/client\.signUp\(email,password,\{nombre,apellidos,fecha_nacimiento:birth\.value/.test(backend));
ok('club/member Auth signup sends fecha_nacimiento',/client\.signUp\(input\.email,input\.password,\{nombre:input\.adulto_nombre,apellidos:input\.adulto_apellidos,fecha_nacimiento:birth\.value/.test(backend));
ok('DOB status RPC wired',/app_kombax_account_birth_date_status_r117/.test(backend));
ok('DOB completion RPC wired',/app_kombax_account_birth_date_set_r117/.test(backend));

ok('global signup has date field',/name:'fecha_nacimiento',label:'Fecha de nacimiento',type:'date',required:true/.test(gateway));
ok('global signup no legacy age checkbox',!/name:'age',label:t\('marketing\.gateway\.auth\.ageConfirm'\)/.test(gateway));
ok('global signup validates 16+',/validateBirthDate\(v\.fecha_nacimiento,\{minAge:16/.test(gateway));
ok('global signup passes DOB',/registerGlobalAccount\(\{\.\.\.v,fecha_nacimiento:birth\.value,accountType:pendingType\}\)/.test(gateway));

ok('member registration DOB required',/adulto_fecha_nacimiento[^\n]*required:true/.test(app));
ok('family adult DOB validated 18+',/minAge:tutor\?18:16/.test(app));
ok('bound student new account asks DOB',/Fecha de nacimiento \(solo cuenta nueva\)/.test(app));
ok('team new account asks DOB',/Obligatoria para crear una cuenta KOMBAX nueva/.test(app));
ok('bound/team register calls pass DOB',((app.match(/fecha_nacimiento:birth\.value/g)||[]).length>=2));

ok('historic account DOB prompt wired in club shell',/promptMissingAccountBirthDate\(\)/.test(app));
ok('historic account DOB prompt wired in global shell',(gateway.match(/promptMissingAccountBirthDate\(\)/g)||[]).length>=2);
ok('DOB helper normalizes ISO',/\^\\d\{4\}-\\d\{2\}-\\d\{2\}\$/.test(birthCore));
ok('DOB prompt explicitly private',/No se muestra en tu perfil público/.test(birthModule));

ok('human error maps missing DOB',/KOMBAX_ACCOUNT_BIRTH_DATE_REQUIRED/.test(utils));
ok('human error maps invalid DOB',/KOMBAX_ACCOUNT_BIRTH_DATE_INVALID/.test(utils));
ok('human error maps duplicate email',/user already registered/.test(utils));

ok('pilot Club migration disables approval requirement',/approval_required',false/.test(m307));
ok('pilot Club migration auto provisions',/app_kombax_pilot_club_autoprovision_r117/.test(m307));
ok('pilot UI no authorization wording',!/Confirmo que estoy autorizado para dar de alta este Club|Debes confirmar que estás autorizado para registrar el Club/i.test(gateway));
ok('birth migration requires auth metadata DOB',/new\.raw_user_meta_data->>'fecha_nacimiento'/.test(m308));
ok('birth migration includes historical canonical backfill',/canonical_backfill/.test(m308));
ok('taxonomy includes Media',/jsonb_build_object\('code','media'/.test(m308));

const { validateBirthDate }=await import('../web/js/core/account-birth-date.js');
const adult=validateBirthDate('1992-11-21',{minAge:16});
ok('DOB helper accepts valid adult ISO',adult.value==='1992-11-21'&&adult.age>=16);
let rejected=false;try{validateBirthDate('2030-01-01')}catch{rejected=true}ok('DOB helper rejects future date',rejected);
rejected=false;try{validateBirthDate('2015-01-01',{minAge:16})}catch{rejected=true}ok('DOB helper enforces configured minimum age',rejected);

console.log(`PASS ${checks.length}/${checks.length} · KOMBAX R117 build 20172 registration contract`);
for(const name of checks)console.log(`  ✓ ${name}`);
